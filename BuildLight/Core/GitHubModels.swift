import Foundation

// MARK: - 状态语义

/// GitHub Actions 的状态取值会随平台演进新增，所以一律按原始字符串解码，
/// 再映射到语义枚举，遇到未知值降级为 `.unknown` 而不是解码失败。
enum RunStatus: String, Sendable {
    case queued
    case inProgress = "in_progress"
    case completed
    case requested
    case waiting
    case pending
    case unknown

    init(raw: String) {
        self = RunStatus(rawValue: raw) ?? .unknown
    }

    var isActive: Bool {
        switch self {
        case .queued, .inProgress, .requested, .waiting, .pending: return true
        case .completed, .unknown: return false
        }
    }

    var label: String {
        switch self {
        case .queued: return "排队中"
        case .inProgress: return "构建中"
        case .completed: return "已完成"
        case .requested: return "已请求"
        case .waiting: return "等待中"
        case .pending: return "待处理"
        case .unknown: return "未知"
        }
    }
}

enum RunConclusion: String, Sendable {
    case success
    case failure
    case cancelled
    case timedOut = "timed_out"
    case skipped
    case neutral
    case actionRequired = "action_required"
    case startupFailure = "startup_failure"
    case stale
    case unknown

    init(raw: String?) {
        guard let raw else { self = .unknown; return }
        self = RunConclusion(rawValue: raw) ?? .unknown
    }

    var label: String {
        switch self {
        case .success: return "成功"
        case .failure: return "失败"
        case .cancelled: return "已取消"
        case .timedOut: return "超时"
        case .skipped: return "已跳过"
        case .neutral: return "中性"
        case .actionRequired: return "需处理"
        case .startupFailure: return "启动失败"
        case .stale: return "已过期"
        case .unknown: return "—"
        }
    }
}

// MARK: - 运行记录

struct WorkflowRun: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String?
    let headBranch: String?
    let headSha: String
    let displayTitle: String?
    let runNumber: Int
    let event: String
    let statusRaw: String
    let conclusionRaw: String?
    let createdAt: Date
    let runStartedAt: Date?
    let updatedAt: Date
    let htmlUrl: URL
    let workflowId: Int?
    let runAttempt: Int?
    let actor: Actor?

    var status: RunStatus { RunStatus(raw: statusRaw) }
    var conclusion: RunConclusion { RunConclusion(raw: conclusionRaw) }
    var isActive: Bool { status.isActive }

    /// 排队时长：从创建到真正拿到 runner 的时间。
    var queueDuration: TimeInterval? {
        guard let started = runStartedAt else { return nil }
        return max(0, started.timeIntervalSince(createdAt))
    }

    enum CodingKeys: String, CodingKey {
        case id, name, event, actor
        case headBranch = "head_branch"
        case headSha = "head_sha"
        case displayTitle = "display_title"
        case runNumber = "run_number"
        case statusRaw = "status"
        case conclusionRaw = "conclusion"
        case createdAt = "created_at"
        case runStartedAt = "run_started_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
        case workflowId = "workflow_id"
        case runAttempt = "run_attempt"
    }
}

struct Actor: Decodable, Hashable, Sendable {
    let login: String
    let avatarUrl: URL?
}

// MARK: - 任务与步骤

struct WorkflowJob: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let statusRaw: String
    let conclusionRaw: String?
    let startedAt: Date?
    let completedAt: Date?
    let steps: [WorkflowStep]

    var status: RunStatus { RunStatus(raw: statusRaw) }
    var conclusion: RunConclusion { RunConclusion(raw: conclusionRaw) }

    enum CodingKeys: String, CodingKey {
        case id, name, steps
        case statusRaw = "status"
        case conclusionRaw = "conclusion"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct WorkflowStep: Decodable, Identifiable, Hashable, Sendable {
    let name: String
    let number: Int
    let statusRaw: String
    let conclusionRaw: String?
    let startedAt: Date?
    let completedAt: Date?

    var id: Int { number }
    var status: RunStatus { RunStatus(raw: statusRaw) }
    var conclusion: RunConclusion { RunConclusion(raw: conclusionRaw) }

    enum CodingKeys: String, CodingKey {
        case name, number
        case statusRaw = "status"
        case conclusionRaw = "conclusion"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

// MARK: - 产物

struct Artifact: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let sizeInBytes: Int
    let expired: Bool
    let createdAt: Date
    let expiresAt: Date?
    let archiveDownloadUrl: URL

    var sizeText: String { ByteCountFormatter.string(fromByteCount: Int64(sizeInBytes), countStyle: .file) }

    enum CodingKeys: String, CodingKey {
        case id, name, expired
        case sizeInBytes = "size_in_bytes"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case archiveDownloadUrl = "archive_download_url"
    }
}

// MARK: - 分页信封

struct RunsPage: Decodable, Sendable {
    let totalCount: Int
    let workflowRuns: [WorkflowRun]
}

struct JobsPage: Decodable, Sendable {
    let jobs: [WorkflowJob]
}

struct ArtifactsPage: Decodable, Sendable {
    let totalCount: Int
    let artifacts: [Artifact]
}

struct RepositorySummary: Decodable, Sendable {
    let fullName: String
    let `private`: Bool
    let defaultBranch: String?
    let pushedAt: Date?
}
