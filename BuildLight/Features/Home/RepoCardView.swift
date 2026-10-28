import SwiftUI
import SwiftData

/// 仓库玻璃卡片。网格里的一格。
struct RepoCardView: View {
    @Environment(AppEnvironment.self) private var environment
    let repo: RepoRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                Text(repo.displayName)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                    .padding(.top, 5)
            }

            Text(subtitle)
                .font(.tag)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 3)

            Spacer(minLength: 8)

            HStack(alignment: .lastTextBaseline) {
                Text(metricText)
                    .font(.metric(.title2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                if let artifact {
                    PackageButton(artifact: artifact)
                }
            }

            progressBar
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .glassCard(padding: 14, cornerRadius: Metrics.radiusL)
        .opacity(repo.hasWorkflows || repo.isRunning ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(repo.displayName)，\(subtitle)，\(metricText)")
    }

    private var latest: RunRecord? { repo.latestRun }

    private var artifact: ArtifactRecord? {
        (latest?.artifacts ?? [])
            .filter { !$0.expired }
            .max { score($0.name) < score($1.name) }
    }

    private var subtitle: String {
        guard let latest else { return "暂无构建记录" }
        var parts: [String] = []
        if let workflow = latest.workflowName, !workflow.isEmpty { parts.append(workflow) }
        if let branch = latest.branch, !branch.isEmpty { parts.append(branch) }
        return parts.joined(separator: " · ")
    }

    private var metricText: String {
        guard let latest else { return "—" }
        guard let start = latest.startedAt else { return "排队" }
        let end = latest.isActive ? Date() : latest.updatedAt
        let total = max(0, Int(end.timeIntervalSince(start)))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
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

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(statusColor)
                    .frame(width: proxy.size.width * ratio)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private var ratio: Double {
        guard let latest else { return 0 }
        if latest.isActive { return 0.55 }
        return latest.conclusion == .success ? 1 : 0.8
    }

    private func score(_ name: String) -> Int {
        let lowered = name.lowercased()
        if lowered.contains("ipa") { return 2 }
        if lowered.contains("unsigned") || lowered.contains("build") { return 1 }
        return 0
    }
}
