import Foundation
import Observation
import ZIPFoundation

/// 取包流程：下载（后台会话，可跨挂起）→ 解压 → 落进缓存 → 交给系统分享面板。
@MainActor
@Observable
final class PackageService {
    enum State: Equatable {
        case idle
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

    init(session: GitHubSession, cache: CacheStore) {
        self.session = session
        self.cache = cache
    }

    func state(for artifactID: Int) -> State {
        if let state = states[artifactID] { return state }
        if let url = cache.url(for: artifactID) { return .ready(url) }
        return .idle
    }

    func start(_ target: PackageTarget) {
        guard tasks[target.id] == nil else { return }
        guard let token = session.token else {
            states[target.id] = .failed(.unauthorized)
            return
        }

        states[target.id] = .downloading(0)
        lastProgress[target.id] = 0
        tasks[target.id] = Task { [weak self] in
            guard let self else { return }
            defer { self.tasks[target.id] = nil }
            do {
                var request = URLRequest(url: target.archiveURL)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

                let zipURL = try await BackgroundDownloadCenter.shared.download(
                    request,
                    artifactID: target.id,
                    name: target.name
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, case .downloading = self.states[target.id] else { return }
                        let previous = self.lastProgress[target.id] ?? 0
                        guard progress >= 1 || progress - previous >= 0.01 else { return }
                        self.lastProgress[target.id] = progress
                        self.states[target.id] = .downloading(progress)
                    }
                }

                self.states[target.id] = .unzipping
                let stored = try self.finalize(zipURL: zipURL, id: target.id)
                self.states[target.id] = .ready(stored)
            } catch {
                self.states[target.id] = .failed(AppError.map(error))
            }
        }
    }

    /// App 回到前台时调用：把系统在后台替我们下完的文件解压入库。
    /// 解压不在后台做——ZIPFoundation 不适合在被挂起的进程里跑。
    func resumeBackgroundDownloads() {
        for pending in BackgroundDownloadCenter.pendingDownloads() {
            guard tasks[pending.artifactID] == nil else { continue }
            guard BackgroundDownloadCenter.takePending(artifactID: pending.artifactID) != nil else { continue }

            states[pending.artifactID] = .unzipping
            tasks[pending.artifactID] = Task { [weak self] in
                guard let self else { return }
                defer { self.tasks[pending.artifactID] = nil }
                do {
                    let stored = try self.finalize(
                        zipURL: URL(fileURLWithPath: pending.path),
                        id: pending.artifactID
                    )
                    self.states[pending.artifactID] = .ready(stored)
                } catch {
                    self.states[pending.artifactID] = .failed(AppError.map(error))
                }
            }
        }
    }

    func reset(_ artifactID: Int) {
        tasks[artifactID]?.cancel()
        tasks[artifactID] = nil
        lastProgress[artifactID] = nil
        states[artifactID] = nil
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
