import SwiftUI

/// 仓库详情页里需要二次确认的远端操作。
///
/// 取消/重跑都会真的动 CI 上正在跑（或刚跑完）的任务，
/// 一滑就执行太危险；而且误触一次要等下一次构建才能纠正。
enum PendingAction: Identifiable {
    case cancel(RunRecord)
    case rerun(RunRecord)

    var id: Int {
        switch self {
        case .cancel(let run), .rerun(let run): run.id
        }
    }

    var title: String {
        switch self {
        case .cancel(let run): "取消 #\(run.number)？"
        case .rerun(let run): "重新运行 #\(run.number)？"
        }
    }

    var confirmTitle: String {
        switch self {
        case .cancel: "取消运行"
        case .rerun: "重新运行"
        }
    }

    var isDestructive: Bool {
        if case .cancel = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .cancel:
            "会立即中止 GitHub 上正在执行的任务。"
        case .rerun:
            "会用同样的提交和分支再跑一次，不会影响已有记录。"
        }
    }

    @MainActor
    func perform(_ environment: AppEnvironment) async {
        guard let client = environment.session.client else { return }
        let run = repoRun
        let parts = run.repoFullName.split(separator: "/")
        guard parts.count == 2 else { return }
        let owner = String(parts[0])
        let repo = String(parts[1])

        switch self {
        case .cancel:
            try? await client.cancel(owner: owner, repo: repo, runID: run.id)
        case .rerun:
            try? await client.rerun(owner: owner, repo: repo, runID: run.id)
        }
        await environment.monitor.refreshNow()
    }

    private var repoRun: RunRecord {
        switch self {
        case .cancel(let run), .rerun(let run): run
        }
    }
}
