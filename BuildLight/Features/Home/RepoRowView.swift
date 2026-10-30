import SwiftUI

/// 首页的一行。列表而不是卡片：
/// 19 个仓库用卡片会有 19 个圆角盒子互相打架，列表靠发丝线分隔，
/// 名字、耗时、状态各归各位，扫视成本低一半。
struct RepoRowView: View {
    @Environment(AppEnvironment.self) private var environment
    let repo: RepoRecord

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            statusDot
                .frame(width: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(repo.displayName)
                    .font(.system(size: 15.5, weight: .semibold))
                    .tracking(-0.1)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                RepoDurationText(
                    startedAt: repo.latestStartedAt,
                    latestAt: repo.latestRunAt,
                    isRunning: repo.isRunning,
                    tint: tone,
                    size: 20
                )
                Text(whenText)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            if let target {
                PackageButton(target: target, compact: true)
                    .padding(.leading, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(alignment: .top) {
            if repo.isRunning {
                StatusTone.running.opacity(0.055)
            }
        }
        .overlay(alignment: .bottom) {
            if repo.isRunning {
                IndeterminateBar(height: 2)
            } else {
                Rectangle()
                    .fill(.quaternary.opacity(0.5))
                    .frame(height: 0.5)
                    .padding(.leading, 58)
            }
        }
        .opacity(repo.hasWorkflows || repo.isRunning ? 1 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(repo.displayName)，\(subtitle)，\(whenText)")
    }

    @ViewBuilder
    private var statusDot: some View {
        if repo.isRunning {
            PulsingDot(size: 6)
        } else {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
        }
    }

    private var subtitle: String {
        guard repo.latestRunAt != nil else { return "暂无构建记录" }
        var parts: [String] = []
        if let workflow = repo.latestWorkflowName, !workflow.isEmpty { parts.append(workflow) }
        if let branch = repo.latestBranch, !branch.isEmpty { parts.append(branch) }
        return parts.joined(separator: " · ")
    }

    private var whenText: String {
        guard let started = repo.latestStartedAt else {
            return repo.latestRunAt == nil ? "—" : "等待 runner"
        }
        if repo.isRunning {
            return started.formatted(date: .omitted, time: .shortened) + " 开始"
        }
        return RelativeTime.text(for: repo.latestRunAt ?? started)
    }

    private var tone: Color? {
        if repo.isRunning { return StatusTone.running }
        if repo.latestFailed { return StatusTone.failed }
        return nil
    }

    private var dotColor: Color {
        if repo.latestFailed { return StatusTone.failed }
        if repo.latestRunAt == nil { return StatusTone.idle.opacity(0.45) }
        return StatusTone.idle
    }

    private var target: PackageTarget? {
        guard let id = repo.packageID,
              let name = repo.packageName,
              let url = repo.packageURL
        else { return nil }
        return PackageTarget(id: id, name: name, archiveURL: url)
    }
}
