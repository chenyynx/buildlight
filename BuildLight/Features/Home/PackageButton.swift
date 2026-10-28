import SwiftUI

/// 取包入口：下载（带进度）→ 解压 → 交给系统分享面板。
struct PackageButton: View {
    @Environment(AppEnvironment.self) private var environment
    let target: PackageTarget

    var body: some View {
        switch environment.packages.state(for: target.id) {
        case .idle:
            Button("下载构建产物", systemImage: "arrow.down") {
                environment.packages.start(target)
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
            .accessibilityLabel("导入 \(target.name)")

        case .failed:
            Button("重试下载", systemImage: "arrow.clockwise") {
                environment.packages.start(target)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
        }
    }
}
