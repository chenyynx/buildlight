import Foundation
import Observation
import ZIPFoundation

/// 产物取用流程：下载 → 解压 → 找到 ipa → 交给系统分享面板（全能签/AltStore）。
/// 全程只用一份临时副本，交接完成即清理。
@MainActor
@Observable
final class PackageService {
    enum State: Equatable {
        case idle
        case downloading
        case unzipping
        case ready(URL)
        case failed(AppError)
    }

    /// key 是 artifact.id
    private(set) var states: [Int: State] = [:]
    private var tasks: [Int: Task<Void, Never>] = [:]

    private let session: GitHubSession

    init(session: GitHubSession) {
        self.session = session
    }

    func state(for artifactID: Int) -> State {
        states[artifactID] ?? .idle
    }

    // MARK: 主流程

    func start(_ artifact: Artifact) {
        guard tasks[artifact.id] == nil else { return }
        guard let client = session.client else {
            states[artifact.id] = .failed(.unauthorized)
            return
        }

        states[artifact.id] = .downloading
        tasks[artifact.id] = Task { [weak self] in
            guard let self else { return }
            do {
                let zipURL = try await client.downloadArtifact(artifact)
                defer { try? FileManager.default.removeItem(at: zipURL) }

                self.states[artifact.id] = .unzipping
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent("bl-unzip-\(artifact.id)-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                try FileManager.default.unzipItem(at: zipURL, to: destination)

                guard let ipa = Self.firstIPA(in: destination) else {
                    throw AppError.packageMissing
                }
                // 挪到固定名字，分享面板里显示得好看
                let named = destination.appendingPathComponent(ipa.lastPathComponent)
                self.states[artifact.id] = .ready(named)
            } catch {
                self.states[artifact.id] = .failed(AppError.map(error))
            }
            self.tasks[artifact.id] = nil
        }
    }

    func reset(_ artifactID: Int) {
        tasks[artifactID]?.cancel()
        tasks[artifactID] = nil
        if case .ready(let url) = state(for: artifactID) {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
        states[artifactID] = .idle
    }

    /// 清理所有已下载但不再使用的产物。
    func purgeReadyFiles(except keep: Set<Int> = []) {
        for (id, state) in states where !keep.contains(id) {
            if case .ready(let url) = state {
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            }
            states[id] = .idle
        }
    }

    // MARK: 工具

    nonisolated private static func firstIPA(in directory: URL) -> URL? {
        let keys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in enumerator where url.pathExtension.lowercased() == "ipa" {
            return url
        }
        return nil
    }
}
