import ActivityKit
import Foundation

/// App 与锁屏组件共享的活动描述。
/// 只放标量：内容状态上限 4KB，塞不下整个模型。
struct BuildActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var running: [RunningBuild]
        var finishedCount: Int
        var failedCount: Int
        /// 当前强调色（浅色 / 深色两种取值，十六进制）。
        /// 锁屏组件拿不到 App 的环境，只能由 App 在更新时带过来；
        /// 留 optional 是为了兼容已经存在的旧 Activity 状态。
        var accentLightHex: String?
        var accentDarkHex: String?
    }

    var title: String
}

struct RunningBuild: Codable, Hashable, Identifiable {
    var id: String
    var repo: String
    var branch: String
    var startedAt: Date
}
