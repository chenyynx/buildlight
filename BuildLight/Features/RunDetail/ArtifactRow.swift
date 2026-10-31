import SwiftUI
import UIKit

struct ArtifactRow: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accent) private var accent
    let artifact: ArtifactRecord

    private var state: PackageService.State {
        environment.packages.state(for: artifact.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .scaledFont(size: 14)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 3) {
                Text(artifact.name)
                    .scaledFont(size: 14, weight: .medium)
                    .lineLimit(1)

                Text(detail)
                    .scaledFont(size: 11.5)
                    .foregroundStyle(isDownloading ? AnyShapeStyle(accent.primary) : AnyShapeStyle(.tertiary))
                    .monospacedDigit()
                    .lineLimit(1)

                if case .downloading(let progress) = state {
                    DownloadProgressBar(progress: progress, height: 3)
                        .padding(.top, 2)
                } else if case .paused(let progress) = state {
                    DownloadProgressBar(progress: progress, height: 3)
                        .opacity(0.5)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            if artifact.expired {
                Text("已过期")
                    .scaledFont(size: 11)
                    .foregroundStyle(.tertiary)
            } else {
                if let webURL = artifact.webDownloadURL {
                    CopyLinkButton(url: webURL, compact: true)
                }
                PackageButton(
                    target: PackageTarget(
                        id: artifact.id,
                        name: artifact.name,
                        archiveURL: artifact.downloadURL,
                        repoName: artifact.run?.repo?.name ?? "",
                        runNumber: artifact.run?.number ?? 0,
                        branch: artifact.run?.branch ?? "",
                        workflowName: artifact.run?.workflowName ?? ""
                    ),
                    compact: true
                )
            }
        }
        .padding(.horizontal, DS.pad)
        // 长按也能复制，给习惯手势的人一条路。
        .contextMenu {
            if let webURL = artifact.webDownloadURL {
                Button("复制下载直链", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = webURL.absoluteString
                }
                Button("在浏览器打开", systemImage: "safari") {
                    UIApplication.shared.open(webURL)
                }
            }
            Button("复制 API 地址（需 Token，仅调试用）", systemImage: "key") {
                UIPasteboard.general.string = artifact.downloadURL.absoluteString
            }
        }
        .padding(.vertical, 10)
        .animation(.easeOut(duration: 0.18), value: state)
    }

    private var isDownloading: Bool {
        if case .downloading = state { return true }
        return false
    }

    private var detail: String {
        switch state {
        case .downloading(let progress):
            var parts = ["下载中 \(Int(progress * 100))%"]
            if let speed = environment.packages.speed(for: artifact.id), let text = ByteRate.text(speed) {
                parts.append(text)
            }
            parts.append(artifact.sizeText)
            return parts.joined(separator: " · ")
        case .paused(let progress):
            return "已下载 \(Int(progress * 100))% · 点右侧继续"
        case .unzipping:
            return "正在解压 · \(artifact.sizeText)"
        case .ready:
            return "已就绪 · \(artifact.sizeText)"
        case .failed(let error):
            return error.localizedDescription
        default:
            return expiry
        }
    }

    private var expiry: String {
        guard let expires = artifact.expiresAt else { return artifact.sizeText }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expires).day ?? 0
        return days > 0 ? "\(artifact.sizeText) · 剩 \(days) 天" : "\(artifact.sizeText) · 即将过期"
    }
}
