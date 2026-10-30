import SwiftUI

/// 步骤行：一个点、一个名字、右边耗时。不画卡片，靠缩进表达层级。
///
/// 状态不只靠颜色：在跑是橙色实心点、失败是红色叉、
/// 成功是中性空心圈——形状本身带信息，
/// 这样「不使用颜色区分」的用户也能读懂。
struct StepRow: View {
    @Environment(\.accent) private var accent
    let step: WorkflowStep

    var body: some View {
        HStack(spacing: 10) {
            glyph

            Text(step.name)
                .scaledFont(size: 14)
                .foregroundStyle(step.status == .queued ? .tertiary : .primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(duration)
                .scaledFont(size: 12)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, DS.pad + 14)
        .padding(.trailing, DS.pad)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var glyph: some View {
        switch step.status {
        case .inProgress:
            PulsingDot(color: accent.primary, size: 5)
        case .completed:
            if isFailed {
                Image(systemName: "xmark")
                    .scaledFont(size: 8, weight: .black)
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(StatusTone.failed, in: .circle)
            } else {
                Circle()
                    .strokeBorder(StatusTone.idle.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 11, height: 11)
            }
        default:
            Circle()
                .strokeBorder(StatusTone.idle.opacity(0.4), lineWidth: 1.5)
                .frame(width: 11, height: 11)
        }
    }

    private var isFailed: Bool {
        step.conclusion == .failure || step.conclusion == .timedOut
    }

    private var duration: String {
        guard let start = step.startedAt else { return "—" }
        let total = max(0, Int((step.completedAt ?? Date.now).timeIntervalSince(start)))
        return total < 60 ? "\(total)s" : "\(total / 60)m \(total % 60)s"
    }
}
