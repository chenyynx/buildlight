import Foundation
import Observation
import SwiftData

/// 拉取并落库。UI 只读 SwiftData，这里负责把远端状态写进去，
/// 同时维护每张卡片需要的冗余快照字段（避免视图层反复计算）。
@MainActor
@Observable
final class BuildMonitor {
    private let context: ModelContext
    private let session: GitHubSession
    /// 只用来同步下载进度的内存快照，不参与轮询逻辑。
    private weak var packages: PackageService?

    private var nextPollAt: [String: Date] = [:]
    /// 错误生命周期。纯逻辑抽到 `MonitorIssueTracker`，方便单测。
    private var issues = MonitorIssueTracker()

    var errors: [String: AppError] { issues.activeErrors }
    private(set) var isRefreshing = false
    private(set) var lastRefreshAt: Date?
    private var pausedUntil: Date?
    /// 第一次见到某个仓库时不发通知，否则刚装 App 会把历史失败全推一遍。
    private var primedRepos: Set<String> = []
    /// 已经提醒过的包，避免同一份产物反复弹。
    private var announcedPackages: Set<Int> = []
    private var loop: Task<Void, Never>?

    private let activeInterval: TimeInterval = 3
    private let idleInterval: TimeInterval = 60
    private let retryInterval: TimeInterval = 20
    private let historyLimit = 30
    private nonisolated static let fetchRunLimit = 30
    private let maxReposPerTick = 12
    /// 同时在途的仓库刷新数。太高会顶到二级限流，太低又退化成串行。
    private let maxConcurrentRefreshes = 4

    init(context: ModelContext, session: GitHubSession, packages: PackageService? = nil) {
        self.context = context
        self.session = session
        self.packages = packages
    }

    // MARK: 生命周期

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                // 按「下一个仓库什么时候到期」决定睡多久。
                // 固定 1 秒会在全空闲时也每秒唤醒，白白耗电。
                let interval = await self.nextSleepInterval()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// 到下一个仓库该刷新的时间，钳在 0.5s…5s。
    private func nextSleepInterval() -> TimeInterval {
        let now = Date.now
        let due = nextPollAt.values.filter { $0 > now }.map { $0.timeIntervalSince(now) }
        guard let soonest = due.min() else { return 5 }
        return min(max(soonest, 0.5), 5)
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

        // 仓库被删掉或隐藏后，它的错误记录不应该继续挂在界面上。
        issues.prune(keeping: Set(all.filter { !$0.isHidden }.map(\.fullName)))

        let now = Date()
        let due = all
            .filter { !$0.isHidden }
            .filter { (nextPollAt[$0.fullName] ?? .distantPast) <= now }
            .sorted { priority($0) < priority($1) }
            .prefix(maxReposPerTick)
        guard !due.isEmpty else { return }

        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshAt = .now
        }

        // 网络请求并发跑（上限 4），落库仍然回到主线程串行。
        // 之前是一个接一个 await，21 个仓库刷新要等 21 个 RTT 累加。
        let repos = Array(due)
        for repo in repos {
            nextPollAt[repo.fullName] = now.addingTimeInterval(activeInterval)
        }

        // 按「波」并发拉数据，落库仍然在主线程串行。
        //
        // 注意：`RepoRecord` 是 SwiftData 的 @Model，不是 Sendable，
        // 不能直接塞进 TaskGroup。所以并行任务只负责「拿数据」，
        // 返回纯 Sendable 的 (fullName, runs) 结果，再由主线程统一写入。
        var index = 0
        while index < repos.count {
            let end = min(index + maxConcurrentRefreshes, repos.count)
            let batch = Array(repos[index..<end])
            let targets = batch.map {
                (fullName: $0.fullName, owner: $0.owner, name: $0.name)
            }

            let results = await withTaskGroup(
                of: RepoFetchResult.self,
                returning: [RepoFetchResult].self
            ) { group in
                for target in targets {
                    group.addTask {
                        await Self.fetchRuns(for: target, client: client)
                    }
                }
                var collected: [RepoFetchResult] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }

            // 回到主线程逐条落库
            let byName = Dictionary(uniqueKeysWithValues: batch.map { ($0.fullName, $0) })
            for result in results {
                guard let repo = byName[result.fullName] else { continue }
                apply(result, to: repo)
            }
            index = end
        }
    }

    private func priority(_ repo: RepoRecord) -> Int {
        if repo.isRunning { return 0 }
        if repo.latestRunAt != nil { return 1 }
        return 2
    }

    func refreshNow() async {
        nextPollAt.removeAll()
        await refreshAll()
    }

    /// 回到前台时用：把所有仓库都刷一遍，而不是每轮只刷 6 个。
    /// 否则刚回来那几秒里，已经结束的构建还会显示成「进行中」，计时器继续走。
    func refreshAll() async {
        nextPollAt.removeAll()
        for _ in 0..<5 {
            let all = (try? context.fetch(FetchDescriptor<RepoRecord>())) ?? []
            let now = Date()
            let pending = all.filter { !$0.isHidden && (nextPollAt[$0.fullName] ?? .distantPast) <= now }
            if pending.isEmpty { break }
            await tick()
        }
    }

    /// 深链用：本地没有这条 run 时，按 runID 补拉一条并落库。
    /// 找不到对应仓库记录时直接返回 nil，不凭空造一个仓库。
    func ensureRun(repoFullName: String, runID: Int) async -> RunRecord? {
        if let existing = try? context.fetch(
            FetchDescriptor<RunRecord>(predicate: #Predicate { $0.id == runID })
        ).first {
            return existing
        }

        guard let client = session.client else { return nil }
        let parts = repoFullName.split(separator: "/")
        guard parts.count == 2 else { return nil }
        let repoRecord = (try? context.fetch(
            FetchDescriptor<RepoRecord>(predicate: #Predicate { $0.fullName == repoFullName })
        ))?.first

        guard let run = try? await client.run(
            owner: String(parts[0]),
            repo: String(parts[1]),
            runID: runID
        ) else { return nil }

        let record = RunRecord(from: run, repoFullName: repoFullName)
        record.repo = repoRecord
        context.insert(record)
        try? context.save()
        return record
    }

    /// 按需拉某个 run 的产物并落库。
    ///
    /// 首页只对最新两条 run 预拉产物（省配额），
    /// 所以打开老运行详情时这里要能补上——否则「安装包」永远是空的，
    /// 看起来像那次构建没产出，实际是没查过。
    @discardableResult
    func ensureArtifacts(for run: RunRecord) async -> Bool {
        guard let client = session.client else { return false }
        let runID = run.id
        let existing = (try? context.fetch(
            FetchDescriptor<ArtifactRecord>(predicate: #Predicate { $0.runID == runID })
        )) ?? []
        guard existing.isEmpty else { return true }

        let parts = run.repoFullName.split(separator: "/")
        guard parts.count == 2,
              let artifacts = try? await client.artifacts(
                  owner: String(parts[0]),
                  repo: String(parts[1]),
                  runID: runID
              )
        else { return false }

        for artifact in artifacts {
            let record = ArtifactRecord(from: artifact, runID: runID)
            record.run = run
            context.insert(record)
        }
        try? context.save()
        return true
    }

    // MARK: 单个仓库

    // MARK: 网络（可在任意线程执行，只带回 Sendable 数据）

    private struct RepoFetchResult: Sendable {
        let fullName: String
        let runs: [WorkflowRun]
        /// runID → 该 run 的产物。只带最新两条，省配额。
        let artifacts: [Int: [Artifact]]
        let error: AppError?
    }

    private nonisolated static func fetchRuns(
        for target: (fullName: String, owner: String, name: String),
        client: GitHubClient
    ) async -> RepoFetchResult {
        do {
            let runs = try await client.runs(
                owner: target.owner,
                repo: target.name,
                perPage: Self.fetchRunLimit
            )

            var artifacts: [Int: [Artifact]] = [:]
            for run in runs.prefix(2) {
                if let list = try? await client.artifacts(
                    owner: target.owner,
                    repo: target.name,
                    runID: run.id
                ) {
                    artifacts[run.id] = list
                }
            }

            return RepoFetchResult(
                fullName: target.fullName,
                runs: runs,
                artifacts: artifacts,
                error: nil
            )
        } catch {
            return RepoFetchResult(
                fullName: target.fullName,
                runs: [],
                artifacts: [:],
                error: AppError.map(error)
            )
        }
    }

    // MARK: 落库（只在主线程）

    /// 把一次拉取结果写进本地库，并维护卡片快照 / 错误状态。
    private func apply(_ result: RepoFetchResult, to repo: RepoRecord) {
        if let error = result.error {
            // 取消不算失败：切后台、切主题触发的重刷都会取消在途请求。
            guard error != .cancelled else {
                nextPollAt[repo.fullName] = Date().addingTimeInterval(2)
                return
            }
            issues.recordFailure(repo: repo.fullName, error: error, at: .now)

            switch error {
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
            return
        }

        let runs = result.runs
        // 必须在 apply(runs:) 之前取：它里面会把仓库标记成「已见过」，
        // 之后再判断永远是 true，于是装完 App 会把历史包全推一遍。
        let wasPrimed = primedRepos.contains(repo.fullName)

        apply(runs: runs, to: repo)
        issues.recordSuccess(repo: repo.fullName, at: .now)

        let hasActive = runs.contains(where: \.isActive)
        repo.hasWorkflows = !runs.isEmpty

        if runs.isEmpty {
            nextPollAt[repo.fullName] = Date().addingTimeInterval(3600)
        } else {
            nextPollAt[repo.fullName] = Date().addingTimeInterval(hasActive ? activeInterval : idleInterval)
        }

        applyArtifacts(result.artifacts, to: repo, announce: wasPrimed)
    }

    private func apply(runs: [WorkflowRun], to repo: RepoRecord) {
        var byID: [Int: RunRecord] = [:]
        for record in repo.runs { byID[record.id] = record }

        var changed = false
        var finished: [(id: Int, run: WorkflowRun, started: Date?)] = []
        let isFirstSight = !primedRepos.contains(repo.fullName)

        for run in runs {
            if let existing = byID[run.id] {
                let wasActive = existing.isActive
                let before = existing.updatedAt
                existing.apply(run)
                if existing.updatedAt != before { changed = true }
                if wasActive, !existing.isActive, !isFirstSight {
                    finished.append((run.id, run, existing.startedAt))
                }
            } else {
                let record = RunRecord(from: run, repoFullName: repo.fullName)
                record.repo = repo
                context.insert(record)
                byID[run.id] = record
                changed = true
            }
        }

        primedRepos.insert(repo.fullName)

        let ordered = byID.values.sorted { $0.createdAt > $1.createdAt }
        for stale in ordered.dropFirst(historyLimit) {
            context.delete(stale)
        }

        // 维护卡片快照
        let filter = repo.workflowFilter
        let relevant = ordered.filter { filter == nil || filter?.isEmpty == true || $0.workflowName == filter }
        if let latest = relevant.first {
            let snapshot = (
                id: latest.id,
                at: latest.updatedAt,
                started: latest.startedAt,
                status: latest.statusRaw,
                conclusion: latest.conclusionRaw,
                branch: latest.branch,
                workflow: latest.workflowName,
                number: latest.number,
                active: relevant.filter(\.isActive).count
            )
            if repo.latestRunID != snapshot.id
                || repo.latestRunAt != snapshot.at
                || repo.latestStatusRaw != snapshot.status
                || repo.latestConclusionRaw != snapshot.conclusion
                || repo.activeRunCount != snapshot.active {
                changed = true
            }
            repo.latestRunID = snapshot.id
            repo.latestRunAt = snapshot.at
            repo.latestStartedAt = snapshot.started
            repo.latestStatusRaw = snapshot.status
            repo.latestConclusionRaw = snapshot.conclusion
            repo.latestBranch = snapshot.branch
            repo.latestWorkflowName = snapshot.workflow
            repo.latestNumber = snapshot.number
            repo.activeRunCount = snapshot.active

            // 只推「最新那条」的完成事件，矩阵构建的多条 job 不会轮番轰炸
            if let hit = finished.first(where: { $0.id == snapshot.id }) {
                let start = hit.started ?? hit.run.runStartedAt ?? hit.run.createdAt
                let event = BuildEvent(
                    runID: hit.id,
                    repo: repo.displayName,
                    repoFullName: repo.fullName,
                    branch: hit.run.headBranch,
                    number: hit.run.runNumber,
                    conclusion: hit.run.conclusionRaw ?? "",
                    duration: hit.run.updatedAt.timeIntervalSince(start)
                )
                Task { await NotificationService.shared.notify(event) }
            }
        } else {
            repo.latestRunID = nil
            repo.latestRunAt = nil
            repo.latestStartedAt = nil
            repo.latestStatusRaw = ""
            repo.latestConclusionRaw = nil
            repo.activeRunCount = 0
        }

        // 只有真的变了才写库，否则每次轮询都会让 @Query 失效、整张卡片墙重建
        if changed {
            try? context.save()
        }
    }

    /// 把预先拉好的产物写进本地库。
    /// 网络请求已经在 `fetchRuns` 里并发做完，这里不碰网络。
    private func applyArtifacts(
        _ artifactsByRun: [Int: [Artifact]],
        to repo: RepoRecord,
        announce: Bool
    ) {
        for (runID, artifacts) in artifactsByRun {
            let existingIDs = Set(
                ((try? context.fetch(
                    FetchDescriptor<ArtifactRecord>(predicate: #Predicate { $0.runID == runID })
                )) ?? []).map(\.id)
            )
            let runRecord = (try? context.fetch(
                FetchDescriptor<RunRecord>(predicate: #Predicate { $0.id == runID })
            ))?.first

            var artifactsChanged = false
            var insertedIDs: [Int] = []
            for artifact in artifacts where !existingIDs.contains(artifact.id) {
                let record = ArtifactRecord(from: artifact, runID: runID)
                record.run = runRecord
                context.insert(record)
                insertedIDs.append(artifact.id)
                artifactsChanged = true
            }

            // 只有最新一次的产物才写进卡片快照
            if runID == repo.latestRunID {
                if let best = bestPackage(in: artifacts) {
                    if repo.packageID != best.id {
                        // 包刚出现 → 立刻提醒。
                        // 这是这个 App 最有价值的一条通知：
                        // upload-artifact 通常在整条 run 结束前几分钟就完成，
                        // 等 run 完成再通知，用户白等一大截。
                        // 首次见到这个仓库时不推，否则装完 App 会把历史包全推一遍。
                        if announce, !announcedPackages.contains(best.id) {
                            announcedPackages.insert(best.id)
                            let message = (
                                repo: repo.displayName,
                                name: best.name,
                                size: best.sizeInBytes,
                                number: runRecord?.number ?? 0
                            )
                            Task {
                                await NotificationService.shared.notifyPackageReady(
                                    repo: message.repo,
                                    name: message.name,
                                    sizeBytes: message.size,
                                    runNumber: message.number
                                )
                            }
                        }
                        repo.packageID = best.id
                        repo.packageName = best.name
                        repo.packageURL = best.archiveDownloadUrl
                        repo.packageSize = best.sizeInBytes
                        artifactsChanged = true
                    }
                } else if repo.packageID != nil {
                    // 之前把非安装包（例如 code-profile）当成了包，这里清掉
                    repo.packageID = nil
                    repo.packageName = nil
                    repo.packageURL = nil
                    repo.packageSize = 0
                    artifactsChanged = true
                }
            }

            if artifactsChanged {
                try? context.save()
                // 新出现的产物可能在磁盘上有半截下载，补一条内存快照。
                packages?.rememberDiskProgress(artifactIDs: insertedIDs.isEmpty ? artifacts.map(\.id) : insertedIDs)
            }
        }
    }

    private func bestPackage(in artifacts: [Artifact]) -> Artifact? {
        artifacts
            .filter { !$0.expired && PackageFilter.looksLikeIPA($0.name) }
            .max { lhs, rhs in
                let left = score(lhs.name)
                let right = score(rhs.name)
                return left == right ? lhs.sizeInBytes < rhs.sizeInBytes : left < right
            }
    }

    private func score(_ name: String) -> Int {
        let lowered = name.lowercased()
        if lowered.contains("ipa") { return 2 }
        if lowered.contains("unsigned") || lowered.contains("build") { return 1 }
        return 0
    }
}
