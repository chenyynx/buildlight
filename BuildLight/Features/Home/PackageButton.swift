import SwiftUI

/// 取包入口：下载 → 解压 → 交给系统分享面板（全能签/AltStore）。
/// 状态全部来自 PackageService，按钮本身不持有任何流程逻辑。
struct PackageButton: View {
    @Environment(AppEnvironment.self) private var environment
    let artifact: ArtifactRecord
    let run: RunRecord

    var body: some View {
        switch environment.packages.state(for: artifact.id) {
        case .idle:
            Button {
                environment.packages.start(artifact.value)
            } label: {
                control(systemImage: "arrow.down", filled: true, label: "下载构建产物")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下载 \(artifact.name)")
        case .downloading, .unzipping:
            ProgressView()
                .controlSize(.small)
                .frame(width: 38, height: 38)
                .accessibilityLabel("正在准备构建产物")
        case .ready(let url):
            ShareLink(item: url) {
                control(systemImage: "square.and.arrow.up", filled: true, label: "导入")
            }
            .accessibilityLabel("导入 \(artifact.name)")
        case .failed:
            Button {
                environment.packages.start(artifact.value)
            } label: {
                control(systemImage: "arrow.clockwise", filled: false, label: "重试下载")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重试下载 \(artifact.name)")
        }
    }

    private func control(systemImage: String, filled: Bool, label: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(filled ? Color.white : Color.accentColor)
            .frame(width: 34, height: 34)
            .background {
                Circle().fill(filled ? Color.accentColor : Color.accentColor.opacity(0.12))
            }
            .contentShape(.circle)
            .accessibilityLabel(label)
    }
}
