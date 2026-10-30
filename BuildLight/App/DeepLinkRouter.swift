import Foundation
import Observation

/// 深链路由：把「从外部跳进来」收敛成一个待处理意图。
///
/// 目前来源是通知；以后小组件、URL Scheme 也走这里。
///
/// 保留 `repoFullName` 是关键：冷启动时本地库还没有那条记录，
/// 只有 runID 是查不到任何东西的（GitHub 的 run 接口必须带 repo）。
@MainActor
@Observable
final class DeepLinkRouter {
    /// 全局唯一。通知 delegate 是 nonisolated 的，需要一个固定入口。
    static let shared = DeepLinkRouter()

    struct Pending: Equatable, Identifiable {
        let runID: Int
        let repoFullName: String?

        var id: Int { runID }
    }

    private(set) var pending: Pending?

    func open(runID: Int, repoFullName: String?) {
        pending = Pending(runID: runID, repoFullName: repoFullName)
    }

    /// 交给界面层消费一次。取走即清空，避免重复跳转。
    func consume() -> Pending? {
        defer { pending = nil }
        return pending
    }
}
