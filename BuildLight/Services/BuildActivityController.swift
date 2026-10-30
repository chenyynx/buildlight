@preconcurrency import ActivityKit
import Foundation

/// 锁屏 / 灵动岛的构建实时活动。
///
/// 注意：这是「本机实时活动」，不依赖 APNs——自签包拿不到推送权限，
/// 所以状态更新只在 App 进程活着时进行；进程挂起后计时器仍靠系统继续走，
/// 但状态会停在最后一次写入（staleDate 之后系统会置灰）。
@MainActor
final class BuildActivityController {
    static let shared = BuildActivityController()

    /// Activity 不是 Sendable：去掉 actor 隔离声明，避免 Swift 6 的 sending 检查。
    nonisolated(unsafe) private var activity: Activity<BuildActivityAttributes>?
    private let enabled: Bool

    private init() {
        enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        activity = Activity<BuildActivityAttributes>.activities.first
    }

    func sync(running: [RunningBuild], finishedCount: Int, failedCount: Int) async {
        guard enabled else { return }

        guard !running.isEmpty else {
            await end()
            return
        }

        let state = BuildActivityAttributes.ContentState(
            running: running,
            finishedCount: finishedCount,
            failedCount: failedCount
        )
        // 3 分钟收不到更新就让系统把它置灰：App 挂起后没人能结束它，
        // 不设过期的话锁屏上的计时会一直往下走，看着像构建永远跑不完。
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(180))

        if let activity {
            await activity.update(content)
        } else {
            activity = try? Activity.request(
                attributes: BuildActivityAttributes(title: "构建看板"),
                content: content,
                pushType: nil
            )
        }
    }

    func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
