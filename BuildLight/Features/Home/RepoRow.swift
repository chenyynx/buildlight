import SwiftUI
import SwiftData

struct RepoRow: View {
    @Environment(AppEnvironment.self) private var environment
    let repo: RepoRecord

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(durationText)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            if let artifact {
                PackageButton(artifact: artifact)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: 子视图

    private var statusIcon: some View {
        Image(systemName: statusSymbol)
            .font(.body)
            .foregroundStyle(statusColor)
            .frame(width: 28, height: 28)
            .background(statusColor.opacity(0.12), in: .circle)
            .symbolEffect(.rotate, options: .repeating, isActive: isRunning)
            .accessibilityHidden(true)
    }

    // MARK: 数据

    private var runs: [RunRecord] {
        let all = repo.runs.sorted { $0.createdAt > $1.createdAt }
        guard let filter = repo.workflowFilter, !filter.isEmpty else { return all }
        return all.filter { $0.workflowName == filter }
    }

    private var latest: RunRecord? { runs.first }
    private var isRunning: Bool { latest?.isActive == true }

    private var artifact: ArtifactRecord? {
        (latest?.artifacts ?? [])
            .filter { !$0.expired }
            .max { score($0.name) < score($1.name) }
    }

    private var subtitle: String {
        guard let latest else { return "还没有构建记录" }
        var parts: [String] = []
        if let workflow = latest.workflowName, !workflow.isEmpty { parts.append(workflow) }
        if let branch = latest.branch, !branch.isEmpty { parts.append(branch) }
        parts.append("#\(latest.number)")
        return parts.joined(separator: " · ")
    }

    private var statusSymbol: String {
        guard let latest else { return "minus" }
        if latest.isActive { return "arrow.triangle.2.circlepath" }
        switch latest.conclusion {
        case .success: return "checkmark"
        case .failure, .timedOut: return "xmark"
        case .cancelled: return "slash"
        default: return "minus"
        }
    }

    private var statusColor: Color {
        guard let latest else { return .secondary }
        if latest.isActive { return Color.accentColor }
        switch latest.conclusion {
        case .success: return .green
        case .failure, .timedOut: return .red
        default: return .secondary
        }
    }

    private var statusText: String {
        guard let latest else { return "—" }
        if latest.isActive { return "运行中" }
        if let artifact { return artifact.sizeText }
        return latest.conclusion.label
    }

    private var durationText: String {
        guard let latest, let start = latest.startedAt else { return " " }
        let end = latest.isActive ? Date() : latest.updatedAt
        let total = max(0, Int(end.timeIntervalSince(start)))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    private func score(_ name: String) -> Int {
        let lowered = name.lowercased()
        if lowered.contains("ipa") { return 2 }
        if lowered.contains("unsigned") || lowered.contains("build") { return 1 }
        return 0
    }
}
