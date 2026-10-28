import SwiftUI

/// 仓库卡片。只读 RepoRecord 上的标量快照，
/// 不做关系遍历、不排序、不碰磁盘——滚动时每帧的代价接近于零。
struct RepoCardView: View {
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
                    .accessibilityHidden(true)
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
                if let target {
                    PackageButton(target: target)
                }
            }

            CardProgressBar(ratio: progressRatio, color: statusColor)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(14)
        .cardSurface(cornerRadius: Metrics.radiusL)
        .opacity(repo.hasWorkflows || repo.isRunning ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(repo.displayName)，\(subtitle)，\(metricText)")
    }

    private var subtitle: String {
        guard repo.latestRunAt != nil else { return "暂无构建记录" }
        var parts: [String] = []
        if let workflow = repo.latestWorkflowName, !workflow.isEmpty { parts.append(workflow) }
        if let branch = repo.latestBranch, !branch.isEmpty { parts.append(branch) }
        return parts.joined(separator: " · ")
    }

    private var target: PackageTarget? {
        guard let id = repo.packageID,
              let name = repo.packageName,
              let url = repo.packageURL
        else { return nil }
        return PackageTarget(id: id, name: name, archiveURL: url)
    }

    private var metricText: String {
        guard let started = repo.latestStartedAt else {
            return repo.latestRunAt == nil ? "—" : "排队"
        }
        let end = repo.isRunning ? Date() : (repo.latestRunAt ?? started)
        let total = max(0, Int(end.timeIntervalSince(started)))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    private var statusColor: Color {
        if repo.isRunning { return Accent.primary }
        switch repo.latestConclusionRaw {
        case "success": return .green
        case "failure", "timed_out": return .red
        default: return .secondary
        }
    }

    private var progressRatio: Double {
        if repo.isRunning { return 0.55 }
        switch repo.latestConclusionRaw {
        case "success": return 1
        case "failure": return 0.8
        default: return 0
        }
    }
}
