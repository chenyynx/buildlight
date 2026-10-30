import Foundation
import Observation
import UIKit
import ZIPFoundation

/// 取包流程：下载（后台会话，可跨挂起）→ 解压 → 落进缓存 → 交给系统分享面板。
@MainActor
@Observable
final class PackageService {
    enum State: Equatable {
        case idle
        /// 上次没下完，进度在磁盘上，点一下接着下
        case paused(Double)
        case downloading(Double)
        case unzipping
        case ready(URL)
        case failed(AppError)
    }

    private(set) var states: [Int: State] = [:]
    private var tasks: [Int: Task<Void, Never>] = [:]
    /// 进度每 1% 才写一次状态：URLSession 的回调是每个数据块一次，
    /// 原样透传会让整墙卡片每秒重绘几十次。
    private var lastProgress: [Int: Double] = [:]
    /// 实时速率（字节/秒），只用于展示。
    private var speeds: [Int: Double] = [:]

    private let session: GitHubSession
    private let cache: CacheStore
    private let downloader = ResumableDownloader.shared
    /// 用户主动暂停的包。区分它和「下载失败」，
    /// 否则点一下暂停会弹出一个「重试」的错误态。
    private var pausedByUser: Set<Int> = []
    /// 每次 start 生成一个 token。旧 Task 结束时不看 token 就清 tasks[id]，
    /// 会把用户刚点「继续」新建的那个 task 引用一起抹掉——
    /// 于是第三次点击又能起一个下载，两个流写同一个 .part。
    private var generations: [Int: UUID] = [:]

    init(session: GitHubSession, cache: CacheStore) {
        self.session = session
        self.cache = cache
    }

    func speed(for artifactID: Int) -> Double? {
        guard let speed = speeds[artifactID], speed > 1 else { return nil }
        return speed
    }

    func state(for artifactID: Int) -> State {
        if let state = states[artifactID] { return state }
        if let url = cache.url(for: artifactID) { return .ready(url) }
        if let progress = downloader.progressOnDisk(for: artifactID) { return .paused(progress) }
        return .idle
    }

    func start(_ target: PackageTarget) {
        guard tasks[target.id] == nil else { return }
        guard let token = session.token else {
            states[target.id] = .failed(.unauthorized)
            return
        }

        // 有半截文件就从它的进度接着显示，不要跳回 0% 骗人
        lastProgress[target.id] = downloader.progressOnDisk(for: target.id) ?? 0
        states[target.id] = .downloading(lastProgress[target.id] ?? 0)

        let generation = UUID()
        generations[target.id] = generation

        tasks[target.id] = Task { [weak self] in
            guard let self else { return }
            defer {
                // 只有「这一代」还活着才清理，避免旧任务踩掉新任务。
                if self.generations[target.id] == generation {
                    self.tasks[target.id] = nil
                    self.generations[target.id] = nil
                }
            }
            do {
                var request = URLRequest(url: target.archiveURL)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

                let zipURL = try await self.download(request, target: target)
                guard self.generations[target.id] == generation else { return }

                self.states[target.id] = .unzipping
                let stored = try self.finalize(zipURL: zipURL, target: target)
                self.states[target.id] = .ready(stored)
            } catch {
                // 这一代已经被 pause / 新的 start 取代 → 什么状态都不要再写，
                // 否则旧任务会把新任务的「下载中」覆盖成「已暂停」或「失败」。
                guard self.generations[target.id] == generation else { return }

                if error is CancellationError || self.pausedByUser.contains(target.id) {
                    // 暂停：保留已下载的字节，状态回到 paused
                    let progress = self.downloader.progressOnDisk(for: target.id) ?? 0
                    self.states[target.id] = progress > 0 ? .paused(progress) : .idle
                } else {
                    self.states[target.id] = .failed(AppError.map(error))
                }
                self.pausedByUser.remove(target.id)
            }
        }
    }

    /// 先走后台通道；它 12 秒没动静就在内部判死刑并抛错，这里当场换成普通会话，
    /// 用户不需要再点一次。
    private func download(_ request: URLRequest, target: PackageTarget) async throws -> URL {
        let progress: @Sendable (Double, Double) -> Void = { [weak self] value, bytesPerSecond in
            Task { @MainActor [weak self] in
                guard let self, case .downloading = self.states[target.id] else { return }
                self.speeds[target.id] = bytesPerSecond
                let previous = self.lastProgress[target.id] ?? 0
                guard value >= 1 || value - previous >= 0.01 else { return }
                self.lastProgress[target.id] = value
                self.states[target.id] = .downloading(value)
            }
        }

        // 字节直接落盘，App 被杀也丢不了；下次进来按 Range 续传。
        let assertion = UIApplication.shared.beginBackgroundTask(withName: "artifact-download")
        defer {
            if assertion != .invalid {
                UIApplication.shared.endBackgroundTask(assertion)
            }
        }
        return try await downloader.download(
            artifactID: target.id,
            request: request,
            onProgress: progress
        )
    }

    /// 暂停下载。已落盘的字节会保留，下次点继续从断点续传。
    func pause(_ artifactID: Int) {
        pausedByUser.insert(artifactID)
        // 先作废这一代，再取消任务：旧 Task 的 defer 就不会再动 tasks 表。
        generations[artifactID] = nil
        tasks[artifactID]?.cancel()
        tasks[artifactID] = nil
        downloader.pause(artifactID: artifactID)
        let progress = downloader.progressOnDisk(for: artifactID) ?? lastProgress[artifactID] ?? 0
        states[artifactID] = .paused(progress)
        speeds[artifactID] = nil
    }

    func reset(_ artifactID: Int) {
        tasks[artifactID]?.cancel()
        tasks[artifactID] = nil
        lastProgress[artifactID] = nil
        speeds[artifactID] = nil
        states[artifactID] = nil
        downloader.discard(artifactID: artifactID)
        cache.remove(artifactID)
    }

    // MARK: 内部

    private func finalize(zipURL: URL, target: PackageTarget) throws -> URL {
        let id = target.id
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("bl-unzip-\(id)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }

        try FileManager.default.unzipItem(at: zipURL, to: destination)

        guard let ipa = Self.firstIPA(in: destination) else {
            throw AppError.packageMissing
        }
        return try cache.save(
            fileURL: ipa,
            id: id,
            name: target.name,
            fileName: target.friendlyFileName
        )
    }

    nonisolated private static func firstIPA(in directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "ipa" {
            return url
        }
        return nil
    }
}
