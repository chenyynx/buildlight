import SwiftUI

struct RunRow: View {
    let run: RunRecord

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(run.isActive ? "运行中" : run.conclusion.label)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                Text(relativeDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        if let title = run.title, !title.isEmpty { return title }
        return run.workflowName ?? "运行"
    }

    private var secondary: String {
        "#\(run.number) · \(run.branch ?? "—")"
    }

    private var statusColor: Color {
        if run.isActive { return StatusTone.running }
        switch run.conclusion {
        case .success: return StatusTone.idle
        case .failure, .timedOut: return StatusTone.failed
        default: return .secondary
        }
    }

    private var relativeDate: String {
        RelativeTime.text(for: run.createdAt)
    }
}
