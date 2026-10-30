import SwiftUI

/// 取包入口：下载（带进度）→ 解压 → 交给系统分享面板。
/// compact 用在卡片上，只留一个 12pt 的纤细图标，不跟大数字抢位置。
struct PackageButton: View {
    @Environment(AppEnvironment.self) private var environment
    let target: PackageTarget
    var compact: Bool = false

    var body: some View {
        switch environment.packages.state(for: target.id) {
        case .idle:
            Button {
                environment.packages.start(target)
            } label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .foregroundStyle(compact ? AnyShapeStyle(.secondary) : AnyShapeStyle(Accent.primary))
                    .frame(width: compact ? 22 : 34, height: compact ? 22 : 34)
                    .background {
                        if !compact {
                            Circle().fill(Accent.soft)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下载构建产物")

        case .paused(let progress):
            Button {
                environment.packages.start(target)
            } label: {
                DownloadRing(progress: progress, size: compact ? 22 : 32, lineWidth: compact ? 2 : 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("已下载 \(Int(progress * 100))%，点击继续")

        case .downloading(let progress):
            DownloadRing(progress: progress, size: compact ? 22 : 32, lineWidth: compact ? 2 : 3)

        case .unzipping:
            ProgressView()
                .controlSize(.mini)
                .frame(width: compact ? 22 : 30, height: compact ? 22 : 30)
                .accessibilityLabel("正在解压")

        case .ready(let url):
            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .foregroundStyle(Accent.primary)
                    .frame(width: compact ? 22 : 34, height: compact ? 22 : 34)
                    .background {
                        if !compact {
                            Circle().fill(Accent.soft)
                        }
                    }
            }
            .accessibilityLabel("导入 \(target.name)")

        case .failed:
            Button {
                environment.packages.start(target)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .foregroundStyle(StatusTone.failed)
                    .frame(width: compact ? 22 : 34, height: compact ? 22 : 34)
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
}
