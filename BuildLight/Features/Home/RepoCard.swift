import SwiftUI

/// 仓库卡片。首页的主力组件。
///
/// 结构分三层：
/// 1. 状态（呼吸点 / 失败标记）——第一眼扫到的
/// 2. 名字 + 工作流·分支——扫第二眼
/// 3. 耗时——右对齐，等宽数字不跳动
///
/// 有产物时，底部多出一条「可安装」的信息带，
/// 这是用户来这个 App 的真正目的，所以它不能藏在详情页里。
struct RepoCard: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accent) private var accent
    let repo: RepoRecord

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var target: PackageTarget? {
        guard let id = repo.packageID,
              let name = repo.packageName,
              let url = repo.packageURL
        else { return nil }
        return PackageTarget(id: id, name: name, archiveURL: url)
    }

    var body: some View {
        GlassSurface(level: .card, cornerRadius: Metrics.radiusL) {
            VStack(alignment: .leading, spacing: 0) {
                mainRow
                if let target {
                    packageStrip(target)
                }
                if repo.isRunning {
                    IndeterminateBar(height: 2)
                        .padding(.top, 10)
                }
            }
            .padding(16)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(Motion.settle) { appeared = true }
        }
    }

    // MARK: 主行

    private var mainRow: some View {
        HStack(alignment: .center, spacing: 10) {
            StatusGlyph(repo: repo)

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
                    .foregroundStyle(downloading ? AnyShapeStyle(accent.primary) : AnyShapeStyle(.tertiary))
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }

    // MARK: 产物带

    private func packageStrip(_ target: PackageTarget) -> some View {
        HStack(spacing: 8) {
            Image(systemName: packageIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(packageIconColor)

            Text(packageLabel)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 6)

            PackageButton(target: target, compact: true)
        }
        .overlay(alignment: .top) {
            GlassHairline()
        }
        .padding(.top, 12)
    }

    private var packageState: PackageService.State {
        environment.packages.state(for: repo.packageID ?? -1)
    }

    private var packageIcon: String {
        switch packageState {
        case .ready: "checkmark.circle.fill"
        case .downloading, .paused, .unzipping: "arrow.down.circle"
        case .failed: "exclamationmark.triangle.fill"
        default: "shippingbox.fill"
        }
    }

    private var packageIconColor: Color {
        switch packageState {
        case .failed: StatusTone.failed
        default: accent.primary
        }
    }

    private var packageLabel: String {
        let size = repo.packageSize > 0
            ? ByteCountFormatter.string(fromByteCount: Int64(repo.packageSize), countStyle: .file)
            : "安装包"

        switch packageState {
        case .ready: return "已就绪 · \(size)"
        case .downloading(let progress): return "下载中 \(Int(progress * 100))%"
        case .paused(let progress): return "已下载 \(Int(progress * 100))% · 可续传"
        case .unzipping: return "正在解压"
        case .failed: return "下载失败 · 点右侧重试"
        default: return "\(size) · 可安装"
        }
    }

    // MARK: 状态

    private var downloading: Bool {
        guard let target else { return false }
        if case .downloading = environment.packages.state(for: target.id) { return true }
        return false
    }

    private var subtitle: String {
        guard repo.latestRunAt != nil else { return "暂无构建记录" }
        var parts: [String] = []
        if let workflow = repo.latestWorkflowName, !workflow.isEmpty { parts.append(workflow) }
        if let branch = repo.latestBranch, !branch.isEmpty { parts.append(branch) }
        return parts.joined(separator: " · ")
    }

    private var whenText: String {
        if downloading, let target,
           let speed = environment.packages.speed(for: target.id),
           let text = ByteRate.text(speed) {
            return text
        }
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
}

/// 卡片左侧的状态标记。
///
/// 不只靠颜色区分（要考虑「不使用颜色区分」的无障碍设置）：
/// 在跑是呼吸圆点、失败是叉、其余是空心圈，形状本身就带信息。
struct StatusGlyph: View {
    let repo: RepoRecord

    var body: some View {
        Group {
            if repo.isRunning {
                PulsingDot(color: StatusTone.running, size: 6)
            } else if repo.latestFailed {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(StatusTone.failed, in: .circle)
            } else {
                Circle()
                    .strokeBorder(StatusTone.idle.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 12, height: 12)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}
