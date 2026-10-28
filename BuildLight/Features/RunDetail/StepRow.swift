import SwiftUI

struct StepRow: View {
    let step: WorkflowStep

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 18)
                .symbolEffect(.rotate, options: .repeating, isActive: step.status == .inProgress)
                .accessibilityHidden(true)
            Text(step.name)
                .font(.footnote)
                .foregroundStyle(step.status == .inProgress ? .primary : .secondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(duration)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    private var symbol: String {
        if step.status == .inProgress { return "arrow.triangle.2.circlepath" }
        switch step.conclusion {
        case .success: return "checkmark"
        case .failure, .timedOut: return "xmark"
        case .skipped: return "minus"
        default: return "circle.dotted"
        }
    }

    private var color: Color {
        if step.status == .inProgress { return .tint }
        switch step.conclusion {
        case .success: return .secondary
        case .failure, .timedOut: return .red
        default: return .secondary
        }
    }

    private var duration: String {
        guard let start = step.startedAt else { return "—" }
        let total = max(0, Int((step.completedAt ?? Date()).timeIntervalSince(start)))
        return total < 60 ? "\(total)s" : "\(total / 60)m \(total % 60)s"
    }
}
