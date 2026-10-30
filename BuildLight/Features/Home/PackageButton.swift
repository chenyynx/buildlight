import SwiftUI

/// 取包入口：下载（带进度）→ 解压 → 交给系统分享面板。
///
/// **点击区**：图标看起来只有 22pt，但外层统一撑到 44×44 的最小可点区。
/// 视觉大小和信息密度是两回事，手指不会因为图标细就点得准。
struct PackageButton: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accent) private var accent
    let target: PackageTarget
    var compact: Bool = false

    private var glyphSize: CGFloat { compact ? 12 : 14 }

    var body: some View {
        content
            .frame(width: 44, height: 44)
            .contentShape(.rect)
            .sensoryFeedback(.success, trigger: isReady)
            .accessibilityInputLabels(["下载", "取包"])
    }

    @ViewBuilder
    private var content: some View {
        switch environment.packages.state(for: target.id) {
        case .idle:
            Button {
                environment.packages.start(target)
            } label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: glyphSize, weight: .semibold))
                    .foregroundStyle(compact ? AnyShapeStyle(.secondary) : AnyShapeStyle(accent.primary))
                    .frame(width: compact ? 26 : 34, height: compact ? 26 : 34)
                    .background {
                        if !compact {
                            Circle().fill(accent.soft)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下载构建产物")

        case .paused(let progress):
            Button {
                environment.packages.start(target)
            } label: {
                DownloadRing(
                    progress: progress,
                    size: compact ? 22 : 32,
                    lineWidth: compact ? 2 : 3,
                    symbol: "play.fill"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("已下载 \(Int(progress * 100))%，点击继续")

        case .downloading(let progress):
            // 下载中变成「暂停」按钮：能点，点了保留已下载字节。
            Button {
                environment.packages.pause(target.id)
            } label: {
                DownloadRing(
                    progress: progress,
                    size: compact ? 22 : 32,
                    lineWidth: compact ? 2 : 3,
                    symbol: "pause.fill"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("暂停下载")

        case .unzipping:
            ProgressView()
                .controlSize(.mini)
                .frame(width: compact ? 22 : 32)
                .accessibilityLabel("正在解压")

        case .ready(let url):
            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: glyphSize, weight: .semibold))
                    .foregroundStyle(accent.primary)
                    .frame(width: compact ? 26 : 34, height: compact ? 26 : 34)
                    .background {
                        if !compact {
                            Circle().fill(accent.soft)
                        }
                    }
            }
            .accessibilityLabel("导入 \(target.name)")

        case .failed:
            Button {
                environment.packages.start(target)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: glyphSize, weight: .semibold))
                    .foregroundStyle(StatusTone.failed)
                    .frame(width: compact ? 26 : 34, height: compact ? 26 : 34)
                    .background {
                        if !compact {
                            Circle().fill(StatusTone.failed.opacity(0.12))
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重试下载")
        }
    }

    private var isReady: Bool {
        if case .ready = environment.packages.state(for: target.id) { return true }
        return false
    }
}
