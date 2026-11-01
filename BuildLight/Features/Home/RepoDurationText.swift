import SwiftUI

/// 卡片上的耗时。
///
/// 正在跑的时候交给 `ElapsedTimeText`（每秒自走）。
/// 曾经用 `Text(timerInterval: startedAt...Date.distantFuture)`，
/// 结果因为区间跨度是几千年、系统据此把刷新粒度放到极粗，
/// 数字**一直卡在 0:00**。见 `SecondClock` 的注释。
struct RepoDurationText: View {
    let startedAt: Date?
    let latestAt: Date?
    let isRunning: Bool
    var tint: Color? = nil
    var size: CGFloat = 26

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if isRunning, let startedAt, startedAt <= .now {
                ElapsedTimeText(start: startedAt)
            } else if isRunning {
                // 起点在未来 = 远端时钟不可信，宁可不报数也别卡在 0:00。
                Text(startedAt == nil ? "排队" : "运行中")
            } else if let startedAt, let latestAt, latestAt >= startedAt {
                Text(Self.clock(from: startedAt, to: latestAt))
            } else if startedAt != nil {
                // 结束时间早于开始时间：数据自相矛盾，别编一个数字。
                Text("—")
            } else {
                Text(latestAt == nil ? "—" : "排队")
            }
        }
        .font(.system(
            size: size * Type.scaleFactor(for: dynamicTypeSize),
            weight: .semibold
        ))
        .foregroundStyle(tint ?? .primary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    /// 已结束的构建用静态值，避免无意义的逐帧刷新。
    static func clock(from start: Date, to end: Date) -> String {
        clock(seconds: end.timeIntervalSince(start))
    }

    static func clock(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}
