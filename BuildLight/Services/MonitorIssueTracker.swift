import Foundation

/// 刷新错误的生命周期管理（纯逻辑，可单测）。
///
/// 之前是一个只增不减的字典：某个仓库偶发一次超时，
/// 之后全跑通了那条错误还挂着，顶部永远显示「网络不可用」。
/// 这里的规则是：**最近一次成功晚于最近一次失败，这条错误就作废**。
struct MonitorIssueTracker {
    private(set) var lastFailure: [String: (error: AppError, at: Date)] = [:]
    private(set) var lastSuccess: [String: Date] = [:]

    mutating func recordSuccess(repo: String, at date: Date) {
        lastSuccess[repo] = date
        lastFailure[repo] = nil
    }

    /// 取消不算失败，直接忽略。
    mutating func recordFailure(repo: String, error: AppError, at date: Date) {
        guard error != .cancelled else { return }
        lastFailure[repo] = (error, date)
    }

    /// 只保留「仍然成立」的错误。
    var activeErrors: [String: AppError] {
        var result: [String: AppError] = [:]
        for (repo, failure) in lastFailure {
            if let success = lastSuccess[repo], success > failure.at { continue }
            result[repo] = failure.error
        }
        return result
    }

    /// 仓库被删除或隐藏后，它的记录不该继续影响界面。
    mutating func prune(keeping alive: Set<String>) {
        lastFailure = lastFailure.filter { alive.contains($0.key) }
        lastSuccess = lastSuccess.filter { alive.contains($0.key) }
    }

    /// 取最需要用户处理的一条：
    /// 未授权 > 限流 > 断网 > 其他。
    var mostActionable: AppError? {
        activeErrors.values.min { lhs, rhs in
            Self.severity(lhs) < Self.severity(rhs)
        }
    }

    static func severity(_ error: AppError) -> Int {
        switch error {
        case .unauthorized: 0
        case .rateLimited: 1
        case .offline: 2
        case .cancelled: 99
        default: 3
        }
    }
}
