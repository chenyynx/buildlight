import SwiftUI

struct HistoryRunRow: View {
    let run: RunRecord

    var body: some View {
        HStack(spacing: Metrics.s + 2) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Metrics.xs) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(secondary)
                    .font(.tag)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Metrics.s)

            VStack(alignment: .trailing, spacing: Metrics.xs) {
                Text(run.isActive ? "运行中" : run.conclusion.label)
                    .font(.tag)
                    .foregroundStyle(statusColor)
                Text(run.createdAt.formatted(.relative(presentation: .named)))
                    .font(.tag)
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
        var parts = ["#\(run.number)"]
        if let branch = run.branch, !branch.isEmpty { parts.append(branch) }
        if let workflow = run.workflowName, !workflow.isEmpty, title != workflow {
            parts.append(workflow)
        }
        return parts.joined(separator: " · ")
    }

    private var statusColor: Color {
        if run.isActive { return Accent.primary }
        switch run.conclusion {
        case .success: return .green
        case .failure, .timedOut: return .red
        default: return .secondary
        }
    }
}
