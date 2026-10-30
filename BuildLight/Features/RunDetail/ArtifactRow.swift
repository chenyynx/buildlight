import SwiftUI

struct ArtifactRow: View {
    @Environment(AppEnvironment.self) private var environment
    let artifact: ArtifactRecord

    private var state: PackageService.State {
        environment.packages.state(for: artifact.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(artifact.name)
                    .font(.subheadline)
                    .lineLimit(1)

                if case .paused(let progress) = state {
                    DownloadProgressBar(progress: progress, height: 4)
                        .opacity(0.55)
                        .padding(.top, 1)
                    Text("已下载 \(Int(progress * 100))% · \(artifact.sizeText) · 点右侧继续")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else if case .downloading(let progress) = state {
                    DownloadProgressBar(progress: progress, height: 4)
                        .padding(.top, 1)
                    Text("下载中 \(Int(progress * 100))% · \(artifact.sizeText)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Accent.primary)
                } else if case .unzipping = state {
                    DownloadProgressBar(progress: 1, height: 4)
                        .opacity(0.4)
                        .padding(.top, 1)
                    Text("正在解压 · \(artifact.sizeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if artifact.expired {
                Text("已过期")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                PackageButton(
                    target: PackageTarget(
                        id: artifact.id,
                        name: artifact.name,
                        archiveURL: artifact.downloadURL
                    )
                )
            }
        }
        .padding(.vertical, 2)
        .animation(.easeOut(duration: 0.18), value: state)
    }

    private var subtitle: String {
        guard let expires = artifact.expiresAt else { return artifact.sizeText }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expires).day ?? 0
        return days > 0
            ? "\(artifact.sizeText) · 剩 \(days) 天"
            : "\(artifact.sizeText) · 即将过期"
    }
}
