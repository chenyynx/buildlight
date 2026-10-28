import ActivityKit
import Foundation

/// App 与锁屏组件共享的活动描述。
/// 只放标量：内容状态上限 4KB，塞不下整个模型。
struct BuildActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var running: [RunningBuild]
        var finishedCount: Int
        var failedCount: Int
    }

    var title: String
}

struct RunningBuild: Codable, Hashable, Identifiable {
    var id: String
    var repo: String
    var branch: String
    var startedAt: Date
}
