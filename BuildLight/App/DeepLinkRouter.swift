import Foundation
import Observation

/// 深链路由。
///
/// 目前只有一个来源：点通知。但把它独立出来的原因是——
/// 「从别处跳进来」这件事会越来越多（小组件、URL Scheme、快捷指令），
/// 每个入口各自写一套跳转逻辑，很快就会互相打架。
/// 统一收敛成一个待处理意图，由根视图消费。
@MainActor
@Observable
final class DeepLinkRouter {
    /// 需要打开的 run。RootTabView 消费后切到历史页。
    var runToOpen: Int?

    func open(runID: Int) {
        runToOpen = runID
    }

    func consumeRunID() -> Int? {
        defer { runToOpen = nil }
        return runToOpen
    }
}
