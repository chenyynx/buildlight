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

    private let session: GitHubSession
    private let cache: CacheStore
    private let downloader = ResumableDownloader.shared

    init(session: GitHubSession, cache: CacheStore) {
        self.session = session
        self.cache = cache
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
        tasks[target.id] = Task { [weak self] in
            guard let self else { return }
            defer { self.tasks[target.id] = nil }
            do {
                var request = URLRequest(url: target.archiveURL)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

                let zipURL = try await self.download(request, target: target)

                self.states[target.id] = .unzipping
                let stored = try self.finalize(zipURL: zipURL, id: target.id)
                self.states[target.id] = .ready(stored)
            } catch {
                self.states[target.id] = .failed(AppError.map(error))
            }
        }
    }

    /// 先走后台通道；它 12 秒没动静就在内部判死刑并抛错，这里当场换成普通会话，
    /// 用户不需要再点一次。
    private func download(_ request: URLRequest, target: PackageTarget) async throws -> URL {
        let progress: @Sendable (Double) -> Void = { [weak self] value in
            Task { @MainActor [weak self] in
                guard let self, case .downloading = self.states[target.id] else { return }
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

    func reset(_ artifactID: Int) {
        tasks[artifactID]?.cancel()
        tasks[artifactID] = nil
        lastProgress[artifactID] = nil
        states[artifactID] = nil
        downloader.discard(artifactID: artifactID)
        cache.remove(artifactID)
    }

    // MARK: 内部

    private func finalize(zipURL: URL, id: Int) throws -> URL {
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("bl-unzip-\(id)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }

        try FileManager.default.unzipItem(at: zipURL, to: destination)

        guard let ipa = Self.firstIPA(in: destination) else {
            throw AppError.packageMissing
        }
        return try cache.save(fileURL: ipa, id: id, name: ipa.lastPathComponent)
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
