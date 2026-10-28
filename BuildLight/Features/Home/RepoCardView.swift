import SwiftUI

/// 仓库卡片（V2 静音砖 + 液态玻璃）。
///
/// 三层信息：名字 → 工作流·分支 → 等宽数字。
/// 颜色只有两个语义：琥珀 = 正在跑，砖红 = 失败；完成一律中性。
struct RepoCardView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let repo: RepoRecord

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                if repo.isRunning {
                    PulsingDot(size: 5).padding(.top, 5)
                } else {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                        .accessibilityHidden(true)
                }
                Text(repo.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.1)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            // 右上角留给浮在卡片上的下载按钮
            .padding(.trailing, target == nil ? 0 : 30)

            Text(subtitle)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.top, 3)

            Spacer(minLength: 10)

            RepoDurationText(
                startedAt: repo.latestStartedAt,
                latestAt: repo.latestRunAt,
                isRunning: repo.isRunning,
                tint: tone
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .overlay(alignment: .bottom) { edgeIndicator }
        .clipShape(shape)
        .glassCard(cornerRadius: 20, reduceTransparency: reduceTransparency)
        .opacity(repo.hasWorkflows || repo.isRunning ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(repo.displayName)，\(subtitle)，\(timeText)")
    }

    /// 运行中：底边一条流动的琥珀高光。未运行：什么都不画。
    @ViewBuilder
    private var edgeIndicator: some View {
        if let target, let phase = downloadPhase(for: target) {
            DownloadProgressBar(progress: phase.progress, height: 2)
        } else if repo.isRunning {
            IndeterminateBar(height: 2)
        }
    }

    private var subtitle: String {
        guard repo.latestRunAt != nil else { return "暂无构建记录" }
        var parts: [String] = []
        if let workflow = repo.latestWorkflowName, !workflow.isEmpty { parts.append(workflow) }
        if let branch = repo.latestBranch, !branch.isEmpty { parts.append(branch) }
        return parts.joined(separator: " · ")
    }

    private func downloadPhase(for target: PackageTarget) -> (label: String, progress: Double)? {
        switch environment.packages.state(for: target.id) {
        case .downloading(let progress):
            return ("下载中 \(Int(progress * 100))%", progress)
        case .unzipping:
            return ("正在解压…", 1)
        default:
            return nil
        }
    }

    private var target: PackageTarget? {
        guard let id = repo.packageID,
              let name = repo.packageName,
              let url = repo.packageURL
        else { return nil }
        return PackageTarget(id: id, name: name, archiveURL: url)
    }

    private var timeText: String {
        guard let started = repo.latestStartedAt else {
            return repo.latestRunAt == nil ? "还没有构建过" : "等待 runner"
        }
        if repo.isRunning {
            return "\(started.formatted(date: .omitted, time: .shortened)) 开始 · 进行中"
        }
        return RelativeTime.text(for: repo.latestRunAt ?? started)
    }

    private var tone: Color? {
        if repo.isRunning { return StatusTone.running }
        if repo.latestFailed { return StatusTone.failed }
        return nil
    }

    private var statusColor: Color {
        if repo.latestFailed { return StatusTone.failed }
        if repo.latestRunAt == nil { return StatusTone.idle.opacity(0.5) }
        return StatusTone.idle
    }
}
