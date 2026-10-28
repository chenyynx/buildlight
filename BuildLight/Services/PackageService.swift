import Foundation
import Observation
import ZIPFoundation

/// 取包流程：下载（带进度）→ 解压 → 落进缓存 → 交给系统分享面板。
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

    private let session: GitHubSession
    private let cache: CacheStore
    private let downloader = ArtifactDownloader()

    init(session: GitHubSession, cache: CacheStore) {
        self.session = session
        self.cache = cache
    }

    func state(for artifactID: Int) -> State {
        if let state = states[artifactID] { return state }
        if let url = cache.url(for: artifactID) { return .ready(url) }
        return .idle
    }

    func start(_ artifact: Artifact) {
        guard tasks[artifact.id] == nil else { return }
        guard let token = session.token else {
            states[artifact.id] = .failed(.unauthorized)
            return
        }

        states[artifact.id] = .downloading(0)
        tasks[artifact.id] = Task { [weak self] in
            guard let self else { return }
            defer { self.tasks[artifact.id] = nil }
            do {
                var request = URLRequest(url: artifact.archiveDownloadUrl)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

                let zipURL = try await self.downloader.download(request) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, case .downloading = self.states[artifact.id] else { return }
                        self.states[artifact.id] = .downloading(progress)
                    }
                }
                defer { try? FileManager.default.removeItem(at: zipURL) }

                self.states[artifact.id] = .unzipping
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent("bl-unzip-\(artifact.id)-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                try FileManager.default.unzipItem(at: zipURL, to: destination)

                guard let ipa = Self.firstIPA(in: destination) else {
                    throw AppError.packageMissing
                }
                let stored = try self.cache.save(fileURL: ipa, id: artifact.id, name: ipa.lastPathComponent)
                self.states[artifact.id] = .ready(stored)
            } catch {
                self.states[artifact.id] = .failed(AppError.map(error))
            }
        }
    }

    func reset(_ artifactID: Int) {
        tasks[artifactID]?.cancel()
        tasks[artifactID] = nil
        states[artifactID] = nil
        cache.remove(artifactID)
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
