import SwiftUI

/// 卡片上的耗时。
///
/// **为什么不用 `TimelineView(.periodic(...))`**：
/// 它靠 SwiftUI 的刷新调度驱动，App 被系统挂起时这个调度会停，
/// 回到前台后要么等下一次 tick 才动，要么整段卡住——
/// 表现就是「切回来以后计时器不动了」。
/// `Text(timerInterval:countsDown:)` 由渲染层直接驱动，
/// 前后台切换、锁屏解锁都保持准确，还不会每秒钟重建一次视图。
struct RepoDurationText: View {
    let startedAt: Date?
    let latestAt: Date?
    let isRunning: Bool
    var tint: Color? = nil
    var size: CGFloat = 26

    var body: some View {
        Group {
            if isRunning, let startedAt {
                Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
            } else if let startedAt {
                Text(Self.clock(from: startedAt, to: latestAt ?? startedAt))
            } else {
                Text(latestAt == nil ? "—" : "排队")
            }
        }
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(tint ?? .primary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    /// 已结束的构建用静态值，避免无意义的逐帧刷新。
    static func clock(from start: Date, to end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(start)))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}
