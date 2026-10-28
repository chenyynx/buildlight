import SwiftUI

/// 折叠状态下的项目摘要：名字 + 最近一次状态 + 次数。
struct HistoryGroupLabel: View {
    let group: HistoryRepoGroup

    var body: some View {
        HStack(spacing: Metrics.s) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(summary)
                    .font(.tag)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Metrics.s)

            Text("\(group.runs.count)")
                .font(.tag)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var latest: RunRecord? { group.runs.first }

    private var summary: String {
        guard let latest else { return "无记录" }
        var parts: [String] = []
        if latest.isActive {
            parts.append("运行中")
        } else {
            parts.append(latest.conclusion.label)
        }
        parts.append(latest.createdAt.formatted(.relative(presentation: .named)))
        return parts.joined(separator: " · ")
    }

    private var statusColor: Color {
        guard let latest else { return .secondary }
        if latest.isActive { return Accent.primary }
        switch latest.conclusion {
        case .success: return .green
        case .failure, .timedOut: return .red
        default: return .secondary
        }
    }
}
