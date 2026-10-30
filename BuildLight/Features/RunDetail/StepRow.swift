import SwiftUI

/// 步骤行：一个点、一个名字、右边耗时。不画卡片，靠缩进表达层级。
struct StepRow: View {
    let step: WorkflowStep

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)

            Text(step.name)
                .font(.system(size: 14))
                .foregroundStyle(step.status == .queued ? .tertiary : .primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(duration)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, DS.pad + 14)
        .padding(.trailing, DS.pad)
        .padding(.vertical, 6)
    }

    private var color: Color {
        if step.status == .inProgress { return StatusTone.running }
        switch step.conclusion {
        case .failure, .timedOut: return StatusTone.failed
        case .success: return StatusTone.idle
        default: return StatusTone.idle.opacity(0.4)
        }
    }

    private var duration: String {
        guard let start = step.startedAt else { return "—" }
        let total = max(0, Int((step.completedAt ?? Date()).timeIntervalSince(start)))
        return total < 60 ? "\(total)s" : "\(total / 60)m \(total % 60)s"
    }
}
