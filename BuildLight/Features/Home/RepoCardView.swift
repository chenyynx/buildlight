import SwiftUI

/// 仓库卡片。只读 RepoRecord 上的标量快照，
/// 不做关系遍历、不排序、不碰磁盘。
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
                if repo.isRunning {
                    RunningBadge()
                } else {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)
                        .accessibilityHidden(true)
                }
            }

            Text(subtitle)
                .font(.tag)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 3)

            Spacer(minLength: 8)

            HStack(alignment: .lastTextBaseline) {
                RepoDurationText(
                    startedAt: repo.latestStartedAt,
                    latestAt: repo.latestRunAt,
                    isRunning: repo.isRunning
                )
                Spacer(minLength: 4)
                if let target {
                    PackageButton(target: target)
                }
            }

            Text(timeText)
                .font(.tag)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.top, 2)

            CardProgressBar(ratio: progressRatio, color: statusColor)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .padding(14)
        .cardSurface(cornerRadius: Metrics.radiusL)
        .overlay {
            if repo.isRunning {
                RoundedRectangle(cornerRadius: Metrics.radiusL)
                    .strokeBorder(Accent.primary.opacity(0.55), lineWidth: 1)
            }
        }
        .opacity(repo.hasWorkflows || repo.isRunning ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(repo.displayName)，\(subtitle)，\(timeText)")
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

    /// 「14:02 开始 · 已跑 4:12」/「14:02 开始 · 2 小时前」
    private var timeText: String {
        guard let started = repo.latestStartedAt else {
            return repo.latestRunAt == nil ? "还没有构建过" : "等待 runner"
        }
        let start = started.formatted(date: .omitted, time: .shortened)
        if repo.isRunning {
            return "\(start) 开始 · 进行中"
        }
        let relative = (repo.latestRunAt ?? started).formatted(.relative(presentation: .named))
        return "\(start) 开始 · \(relative)"
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
