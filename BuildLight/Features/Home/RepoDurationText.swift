import SwiftUI

/// 卡片上的耗时。
/// 运行中的卡片挂一个每秒的本地时钟，数字会一直走；
/// 已结束的卡片用静态值，避免无意义的逐帧刷新。
struct RepoDurationText: View {
    let startedAt: Date?
    let latestAt: Date?
    let isRunning: Bool
    var tint: Color? = nil

    var body: some View {
        Group {
            if isRunning, let startedAt {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    text(from: startedAt, to: context.date)
                }
            } else if let startedAt {
                text(from: startedAt, to: latestAt ?? startedAt)
            } else {
                Text(latestAt == nil ? "—" : "排队")
            }
        }
        .font(Font.system(size: 26, weight: .semibold).monospacedDigit())
        .foregroundStyle(tint ?? .primary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func text(from start: Date, to end: Date) -> Text {
        let total = max(0, Int(end.timeIntervalSince(start)))
        return Text("\(total / 60):\(String(format: "%02d", total % 60))")
    }
}
