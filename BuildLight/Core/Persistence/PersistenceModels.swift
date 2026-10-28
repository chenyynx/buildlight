import Foundation
import SwiftData

/// 被跟踪的仓库。这是唯一事实源——UI 读它，网络结果写它。
@Model
final class RepoRecord {
    #Unique<RepoRecord>([\.fullName])

    var fullName: String
    var owner: String
    var name: String
    /// 只盯某个工作流时填（例如 "iOS Build"）。
    var workflowFilter: String?
    var sortIndex: Int
    var addedAt: Date
    var lastCheckedAt: Date?
    /// 是否已经发现过工作流记录。没记录的仓库只做低频探测。
    var hasWorkflows: Bool = false
    /// 用户手动隐藏的仓库。
    var isHidden: Bool = false

    // 以下字段是「最近一次运行」的冗余快照。
    // 卡片只读这些标量，不再每帧去遍历关系数组、排序、查磁盘。
    var latestRunAt: Date?
    var latestStartedAt: Date?
    var latestStatusRaw: String = ""
    var latestConclusionRaw: String?
    var latestBranch: String?
    var latestWorkflowName: String?
    var latestNumber: Int = 0
    var latestRunID: Int?
    var activeRunCount: Int = 0

    // 可下载产物（有就取，没有为空）
    var packageID: Int?
    var packageName: String?
    var packageURL: URL?
    var packageSize: Int = 0

    var isRunning: Bool { activeRunCount > 0 }
    var latestFailed: Bool { latestConclusionRaw == "failure" }
    var hasPackage: Bool { packageID != nil }

    @Relationship(deleteRule: .cascade, inverse: \RunRecord.repo)
    var runs: [RunRecord] = []

    init(owner: String, name: String, workflowFilter: String? = nil, sortIndex: Int = 0) {
        self.owner = owner
        self.name = name
        self.fullName = "\(owner)/\(name)"
        self.workflowFilter = workflowFilter
        self.sortIndex = sortIndex
        self.addedAt = .now
    }

    var displayName: String { name }
}

/// 一次工作流运行。只存列表需要的字段，jobs/steps 不落库（按需拉取）。
@Model
final class RunRecord {
    #Unique<RunRecord>([\.id])

    var id: Int
    var repoFullName: String
    var workflowName: String?
    var branch: String?
    var sha: String
    var title: String?
    var number: Int
    var attempt: Int
    var event: String
    var statusRaw: String
    var conclusionRaw: String?
    var createdAt: Date
    var startedAt: Date?
    var updatedAt: Date
    var htmlURL: URL
    var actorLogin: String?
    var repo: RepoRecord?

    @Relationship(deleteRule: .cascade, inverse: \ArtifactRecord.run)
    var artifacts: [ArtifactRecord] = []

    init(from run: WorkflowRun, repoFullName: String) {
        self.id = run.id
        self.repoFullName = repoFullName
        self.workflowName = run.name
        self.branch = run.headBranch
        self.sha = run.headSha
        self.title = run.displayTitle
        self.number = run.runNumber
        self.attempt = run.runAttempt ?? 1
        self.event = run.event
        self.statusRaw = run.statusRaw
        self.conclusionRaw = run.conclusionRaw
        self.createdAt = run.createdAt
        self.startedAt = run.runStartedAt
        self.updatedAt = run.updatedAt
        self.htmlURL = run.htmlUrl
        self.actorLogin = run.actor?.login
    }

    var status: RunStatus { RunStatus(raw: statusRaw) }
    var conclusion: RunConclusion { RunConclusion(raw: conclusionRaw) }
    var isActive: Bool { status.isActive }

    func apply(_ run: WorkflowRun) {
        workflowName = run.name
        branch = run.headBranch
        sha = run.headSha
        title = run.displayTitle
        number = run.runNumber
        attempt = run.runAttempt ?? attempt
        statusRaw = run.statusRaw
        conclusionRaw = run.conclusionRaw
        startedAt = run.runStartedAt
        updatedAt = run.updatedAt
        htmlURL = run.htmlUrl
        actorLogin = run.actor?.login
    }

    /// 转回值类型给网络层/视图用。
    var value: WorkflowRun {
        WorkflowRun(
            id: id,
            name: workflowName,
            headBranch: branch,
            headSha: sha,
            displayTitle: title,
            runNumber: number,
            event: event,
            statusRaw: statusRaw,
            conclusionRaw: conclusionRaw,
            createdAt: createdAt,
            runStartedAt: startedAt,
            updatedAt: updatedAt,
            htmlUrl: htmlURL,
            workflowId: nil,
            runAttempt: attempt,
            actor: actorLogin.map { Actor(login: $0, avatarUrl: nil) }
        )
    }
}

/// 产物元数据。让首页在离线时也知道「包已就绪」。
@Model
final class ArtifactRecord {
    #Unique<ArtifactRecord>([\.id])

    var id: Int
    var runID: Int
    var name: String
    var sizeBytes: Int
    var expired: Bool
    var createdAt: Date
    var expiresAt: Date?
    var downloadURL: URL
    var run: RunRecord?

    init(from artifact: Artifact, runID: Int) {
        self.id = artifact.id
        self.runID = runID
        self.name = artifact.name
        self.sizeBytes = artifact.sizeInBytes
        self.expired = artifact.expired
        self.createdAt = artifact.createdAt
        self.expiresAt = artifact.expiresAt
        self.downloadURL = artifact.archiveDownloadUrl
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }

    var value: Artifact {
        Artifact(
            id: id,
            name: name,
            sizeInBytes: sizeBytes,
            expired: expired,
            createdAt: createdAt,
            expiresAt: expiresAt,
            archiveDownloadUrl: downloadURL
        )
    }
}
