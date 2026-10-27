import Foundation
import Observation

/// 一个被盯着的仓库。
struct TrackedRepo: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(owner)/\(name)" }
    var owner: String
    var name: String
    /// 只盯某个工作流时填（例如 "iOS Build"），留空表示该仓库全部工作流。
    var workflowName: String?
    /// 排序用，越小越靠上。
    var order: Int

    var fullName: String { "\(owner)/\(name)" }
}

/// 首页每个仓库的状态快照。
struct RepoSnapshot: Identifiable, Sendable {
    var id: String { repo.id }
    let repo: TrackedRepo
    var latestRun: WorkflowRun?
    var activeRuns: [WorkflowRun]
    var latestSuccess: WorkflowRun?
    var lastError: String?
    var refreshedAt: Date?

    var isBusy: Bool { !activeRuns.isEmpty }
}

@MainActor
@Observable
final class BuildStore {
    private(set) var repos: [TrackedRepo] = []
    private(set) var snapshots: [RepoSnapshot] = []
    private(set) var token: String?
    private(set) var account: Actor?
    private(set) var isLoading = false
    private(set) var lastRefresh: Date?

    private var client: GitHubClient?
    private var refreshTask: Task<Void, Never>?

    private static let reposKey = "buildlight.trackedRepos"

    init() {
        loadRepos()
        token = Keychain.loadToken()
        if token != nil {
            client = GitHubClient(token: token!)
        }
    }

    // MARK: Token

    func setToken(_ value: String) async throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GitHubError.unauthorized }
        let probe = GitHubClient(token: trimmed)
        let me = try await probe.currentUser()
        Keychain.saveToken(trimmed)
        token = trimmed
        client = probe
        account = me
    }

    func signOut() {
        Keychain.deleteToken()
        token = nil
        account = nil
        client = nil
        snapshots = []
    }

    // MARK: 仓库

    func loadRepos() {
        guard let data = UserDefaults.standard.data(forKey: Self.reposKey),
              let decoded = try? JSONDecoder().decode([TrackedRepo].self, from: data)
        else { return }
        repos = decoded.sorted { $0.order < $1.order }
    }

    private func persistRepos() {
        repos = repos.enumerated().map { index, repo in
            var copy = repo
            copy.order = index
            return copy
        }
        if let data = try? JSONEncoder().encode(repos) {
            UserDefaults.standard.set(data, forKey: Self.reposKey)
        }
    }

    func addRepo(fullName: String) async throws {
        let parts = fullName.split(separator: "/")
        guard parts.count == 2 else { throw GitHubError.notFound }
        guard let client else { throw GitHubError.unauthorized }
        let summary = try await client.repository(owner: String(parts[0]), name: String(parts[1]))
        guard !repos.contains(where: { $0.fullName == summary.fullName }) else { return }
        repos.append(TrackedRepo(owner: String(parts[0]), name: String(parts[1]), workflowName: nil, order: repos.count))
        persistRepos()
        await refresh(force: true)
    }

    func removeRepo(_ repo: TrackedRepo) {
        repos.removeAll { $0.id == repo.id }
        snapshots.removeAll { $0.id == repo.id }
        persistRepos()
    }

    // MARK: 刷新

    func refresh(force: Bool = false) async {
        guard let client, !isLoading else { return }
        if !force, let lastRefresh, Date().timeIntervalSince(lastRefresh) < 2 { return }
        isLoading = true
        defer {
            isLoading = false
            lastRefresh = Date()
        }

        let current = repos
        let results: [RepoSnapshot] = await withTaskGroup(of: RepoSnapshot.self) { group in
            for repo in current {
                group.addTask {
                    await Self.snapshot(for: repo, client: client)
                }
            }
            var collected: [RepoSnapshot] = []
            for await item in group { collected.append(item) }
            return collected.sorted { $0.repo.order < $1.repo.order }
        }
        snapshots = results
    }

    private static func snapshot(for repo: TrackedRepo, client: GitHubClient) async -> RepoSnapshot {
        do {
            let runs = try await client.runs(owner: repo.owner, repo: repo.name, perPage: 12)
            let filtered = repo.workflowName.map { name in runs.filter { $0.name == name } } ?? runs
            let active = filtered.filter(\.isActive)
            let latest = filtered.first
            let latestSuccess = filtered.first { $0.conclusion == .success }
            return RepoSnapshot(
                repo: repo,
                latestRun: latest,
                activeRuns: active,
                latestSuccess: latestSuccess,
                lastError: nil,
                refreshedAt: Date()
            )
        } catch {
            return RepoSnapshot(
                repo: repo,
                latestRun: nil,
                activeRuns: [],
                latestSuccess: nil,
                lastError: error.localizedDescription,
                refreshedAt: Date()
            )
        }
    }

    /// 前台自适应轮询：有活跃构建 3 秒一次，空闲 30 秒一次。
    func startPolling() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh(force: true)
                let busy = self.snapshots.contains(where: \.isBusy)
                let interval: UInt64 = busy ? 3_000_000_000 : 30_000_000_000
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    func stopPolling() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
