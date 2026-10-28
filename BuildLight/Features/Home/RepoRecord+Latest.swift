import Foundation

extension RepoRecord {
    /// 按创建时间倒序，并应用工作流过滤。
    var orderedRuns: [RunRecord] {
        let all = runs.sorted { $0.createdAt > $1.createdAt }
        guard let filter = workflowFilter, !filter.isEmpty else { return all }
        return all.filter { $0.workflowName == filter }
    }

    var latestRun: RunRecord? { orderedRuns.first }

    var runningRuns: [RunRecord] { orderedRuns.filter(\.isActive) }

    var isRunning: Bool { !runningRuns.isEmpty }

    var latestFailed: Bool { latestRun?.conclusion == .failure }
}
