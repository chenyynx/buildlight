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

    private var nextPollAt: [String: Date] = [:]
    private(set) var errors: [String: AppError] = [:]
    private(set) var isRefreshing = false
    private(set) var lastRefreshAt: Date?
    private var pausedUntil: Date?
    private var loop: Task<Void, Never>?

    private let activeInterval: TimeInterval = 3
    private let idleInterval: TimeInterval = 60
    private let retryInterval: TimeInterval = 20
    private let historyLimit = 30
    private let maxReposPerTick = 6

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
            .prefix(maxReposPerTick)
        guard !due.isEmpty else { return }

        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshAt = .now
        }

        for repo in due {
            nextPollAt[repo.fullName] = now.addingTimeInterval(activeInterval)
            await refresh(repo: repo, client: client)
        }
    }

    private func priority(_ repo: RepoRecord) -> Int {
        if repo.isRunning { return 0 }
        if repo.latestRunAt != nil { return 1 }
        return 2
    }

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
            repo.hasWorkflows = !runs.isEmpty

            if runs.isEmpty {
                nextPollAt[repo.fullName] = Date().addingTimeInterval(3600)
            } else {
                nextPollAt[repo.fullName] = Date().addingTimeInterval(hasActive ? activeInterval : idleInterval)
            }

            await loadArtifacts(for: Array(runs.prefix(2)), repo: repo, client: client)
        } catch {
            let mapped = AppError.map(error)
            errors[repo.fullName] = mapped

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
        }
    }

    private func apply(runs: [WorkflowRun], to repo: RepoRecord) {
        var byID: [Int: RunRecord] = [:]
        for record in repo.runs { byID[record.id] = record }

        var changed = false
        for run in runs {
            if let existing = byID[run.id] {
                let before = existing.updatedAt
                existing.apply(run)
                if existing.updatedAt != before { changed = true }
            } else {
                let record = RunRecord(from: run, repoFullName: repo.fullName)
                record.repo = repo
                context.insert(record)
                byID[run.id] = record
                changed = true
            }
        }

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

    private func loadArtifacts(for runs: [WorkflowRun], repo: RepoRecord, client: GitHubClient) async {
        for run in runs {
            let runID = run.id
            guard let artifacts = try? await client.artifacts(
                owner: repo.owner,
                repo: repo.name,
                runID: runID
            ) else { continue }

            let existingIDs = Set(
                ((try? context.fetch(
                    FetchDescriptor<ArtifactRecord>(predicate: #Predicate { $0.runID == runID })
                )) ?? []).map(\.id)
            )
            let runRecord = (try? context.fetch(
                FetchDescriptor<RunRecord>(predicate: #Predicate { $0.id == runID })
            ))?.first

            var artifactsChanged = false
            for artifact in artifacts where !existingIDs.contains(artifact.id) {
                let record = ArtifactRecord(from: artifact, runID: runID)
                record.run = runRecord
                context.insert(record)
                artifactsChanged = true
            }

            // 只有最新一次的产物才写进卡片快照
            if runID == repo.latestRunID, let best = bestPackage(in: artifacts) {
                if repo.packageID != best.id {
                    repo.packageID = best.id
                    repo.packageName = best.name
                    repo.packageURL = best.archiveDownloadUrl
                    repo.packageSize = best.sizeInBytes
                    artifactsChanged = true
                }
            }
            if artifactsChanged { try? context.save() }
        }
    }

    private func bestPackage(in artifacts: [Artifact]) -> Artifact? {
        artifacts
            .filter { !$0.expired }
            .max { score($0.name) < score($1.name) }
    }

    private func score(_ name: String) -> Int {
        let lowered = name.lowercased()
        if lowered.contains("ipa") { return 2 }
        if lowered.contains("unsigned") || lowered.contains("build") { return 1 }
        return 0
    }
}
