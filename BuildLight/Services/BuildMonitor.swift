import Foundation
import Observation
import SwiftData

/// 拉取并落库。UI 不直接调它拿数据——数据从 SwiftData 读，
/// 这里只负责把远端状态写进去。
@MainActor
@Observable
final class BuildMonitor {
    private let context: ModelContext
    private let session: GitHubSession

    /// 每个仓库下一次该拉取的时间，按活跃度自适应。
    private var nextPollAt: [String: Date] = [:]
    /// 每个仓库最近一次错误，用于卡片上的降级提示。
    private(set) var errors: [String: AppError] = [:]
    private(set) var isRefreshing = false
    private(set) var lastRefreshAt: Date?
    /// 触发限流时整体暂停到这个时间。
    private var pausedUntil: Date?

    private var loop: Task<Void, Never>?

    private let activeInterval: TimeInterval = 3
    private let idleInterval: TimeInterval = 45
    private let retryInterval: TimeInterval = 15
    private let historyLimit = 30

    init(context: ModelContext, session: GitHubSession) {
        self.context = context
        self.session = session
    }

    // MARK: 生命周期

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    // MARK: 调度

    private func tick() async {
        guard let client = session.client else { return }
        if let pausedUntil, Date() < pausedUntil { return }

        let all = (try? context.fetch(
            FetchDescriptor<RepoRecord>(sortBy: [SortDescriptor(\.sortIndex)])
        )) ?? []

        let now = Date()
        let due = all
            .filter { !$0.isHidden }
            .filter { (nextPollAt[$0.fullName] ?? .distantPast) <= now }
            .sorted { priority($0) < priority($1) }
            .prefix(6)
        guard !due.isEmpty else { return }

        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshAt = .now
        }

        for repo in due {
            // 先占位，避免下一轮重复触发；网络请求本身是并发的，这里串行的是状态收敛
            nextPollAt[repo.fullName] = now.addingTimeInterval(activeInterval)
            await refresh(repo: repo, client: client)
        }
    }

    /// 正在跑的最优先，其次是有历史的，最后是还没发现工作流的。
    private func priority(_ repo: RepoRecord) -> Int {
        if repo.isRunning { return 0 }
        if repo.latestRun != nil { return 1 }
        return 2
    }

    /// 手动刷新：忽略退避，立刻拉一轮。
    func refreshNow() async {
        nextPollAt.removeAll()
        await tick()
    }

    // MARK: 单个仓库

    private func refresh(repo: RepoRecord, client: GitHubClient) async {
        do {
            let runs = try await client.runs(owner: repo.owner, repo: repo.name, perPage: historyLimit)
            apply(runs: runs, to: repo)
            errors[repo.fullName] = nil

            let hasActive = runs.contains(where: \.isActive)
            let hasHistory = !runs.isEmpty
            repo.hasWorkflows = hasHistory

            if !hasHistory {
                // 没有任何 Actions 记录的仓库，一小时后再看一次
                nextPollAt[repo.fullName] = Date().addingTimeInterval(3600)
            } else {
                nextPollAt[repo.fullName] = Date().addingTimeInterval(hasActive ? activeInterval : idleInterval)
            }

            await loadArtifacts(for: Array(runs.prefix(3)), repo: repo, client: client)
        } catch {
            let mapped = AppError.map(error)
            errors[repo.fullName] = mapped
            repo.lastCheckedAt = .now

            switch mapped {
            case .rateLimited(let resetAt):
                pausedUntil = resetAt
                nextPollAt[repo.fullName] = resetAt ?? Date().addingTimeInterval(300)
            case .unauthorized:
                nextPollAt[repo.fullName] = Date().addingTimeInterval(600)
            case .notFound:
                repo.hasWorkflows = false
                nextPollAt[repo.fullName] = Date().addingTimeInterval(3600)
            default:
                nextPollAt[repo.fullName] = Date().addingTimeInterval(retryInterval)
            }
            try? context.save()
        }
    }

    private func apply(runs: [WorkflowRun], to repo: RepoRecord) {
        if let filter = repo.workflowFilter, !filter.isEmpty {
            // 过滤只影响展示，落库仍存全部，切换过滤条件时无需重新拉取
            _ = filter
        }

        var byID: [Int: RunRecord] = [:]
        for record in repo.runs { byID[record.id] = record }
        for run in runs {
            if let existing = byID[run.id] {
                existing.apply(run)
            } else {
                let record = RunRecord(from: run, repoFullName: repo.fullName)
                record.repo = repo
                context.insert(record)
                byID[run.id] = record
            }
        }

        // 裁剪超出的历史
        let ordered = byID.values.sorted { $0.createdAt > $1.createdAt }
        for stale in ordered.dropFirst(historyLimit) {
            context.delete(stale)
        }

        repo.lastCheckedAt = .now
        try? context.save()
    }

    private func loadArtifacts(for runs: [WorkflowRun], repo: RepoRecord, client: GitHubClient) async {
        guard !runs.isEmpty else { return }
        for run in runs {
            let runID = run.id
            guard let artifacts = try? await client.artifacts(owner: repo.owner, repo: repo.name, runID: runID) else {
                continue
            }
            let existingIDs = Set(
                ((try? context.fetch(
                    FetchDescriptor<ArtifactRecord>(predicate: #Predicate { $0.runID == runID })
                )) ?? []).map(\.id)
            )
            let runRecord = (try? context.fetch(
                FetchDescriptor<RunRecord>(predicate: #Predicate { $0.id == runID })
            ))?.first
            for artifact in artifacts where !existingIDs.contains(artifact.id) {
                let record = ArtifactRecord(from: artifact, runID: runID)
                record.run = runRecord
                context.insert(record)
            }
        }
        try? context.save()
    }
}
