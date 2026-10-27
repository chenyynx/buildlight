import SwiftUI
import SwiftData

/// 首页一行。用系统列表样式，不自绘卡片。
struct RepoRow: View {
    @Environment(AppEnvironment.self) private var environment
    let repo: RepoRecord

    private var runs: [RunRecord] {
        let all = repo.runs.sorted { $0.createdAt > $1.createdAt }
        guard let filter = repo.workflowFilter, !filter.isEmpty else { return all }
        return all.filter { $0.workflowName == filter }
    }

    private var latest: RunRecord? { runs.first }
    private var activeCount: Int { runs.filter(\.isActive).count }

    private var artifact: ArtifactRecord? {
        (latest?.artifacts ?? [])
            .filter { !$0.expired }
            .max { score($0.name) < score($1.name) }
    }

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            VStack(alignment: .leading, spacing: 3) {
                Text(repo.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(durationText)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
            if let artifact, let run = latest {
                PackageButton(artifact: artifact, run: run)
                    .padding(.leading, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.14))
                .frame(width: 30, height: 30)
            Image(systemName: statusSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusColor)
        }
        .overlay {
            if latest?.isActive == true {
                Circle()
                    .strokeBorder(statusColor.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 30, height: 30)
            }
        }
        .accessibilityHidden(true)
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
        if latest.isActive { return .blue }
        switch latest.conclusion {
        case .success: return artifact != nil ? .green : .secondary
        case .failure, .timedOut: return .red
        default: return .secondary
        }
    }

    private var subtitle: String {
        guard let latest else { return "还没有构建记录" }
        var parts: [String] = []
        if let workflow = latest.workflowName, !workflow.isEmpty { parts.append(workflow) }
        if let branch = latest.branch, !branch.isEmpty { parts.append(branch) }
        parts.append("#\(latest.number)")
        if activeCount > 1 { parts.append("另有 \(activeCount - 1) 条在跑") }
        return parts.joined(separator: " · ")
    }

    private var statusText: String {
        guard let latest else { return "—" }
        if latest.isActive { return "运行中" }
        if let artifact { return artifact.sizeText }
        return latest.conclusion.label
    }

    private var durationText: String {
        guard let latest else { return "" }
        guard let start = latest.startedAt else { return "排队" }
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
