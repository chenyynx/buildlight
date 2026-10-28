import SwiftUI

/// 取包入口：下载 → 解压 → 交给系统分享面板（全能签/AltStore）。
/// 状态全部来自 PackageService，视图本身不持有流程。
struct PackageButton: View {
    @Environment(AppEnvironment.self) private var environment
    let artifact: ArtifactRecord

    var body: some View {
        switch environment.packages.state(for: artifact.id) {
        case .idle:
            Button("下载构建产物", systemImage: "arrow.down") {
                environment.packages.start(artifact.value)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)

        case .downloading, .unzipping:
            ProgressView()
                .controlSize(.small)
                .frame(width: 30, height: 30)
                .accessibilityLabel("正在准备构建产物")

        case .ready(let url):
            ShareLink(item: url) {
                Label("导入", systemImage: "square.and.arrow.up")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel("导入 \(artifact.name)")

        case .failed:
            Button("重试下载", systemImage: "arrow.clockwise") {
                environment.packages.start(artifact.value)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
        }
    }
}
