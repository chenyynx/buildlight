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

        case .downloading(let progress):
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .frame(width: 26, height: 26)
                .accessibilityLabel("下载中 \(Int(progress * 100))%")

        case .unzipping:
            ProgressView()
                .controlSize(.small)
                .frame(width: 30, height: 30)
                .accessibilityLabel("正在解压")

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
