import SwiftUI

/// 产物页里的一张包卡片。
///
/// 主操作是「导入」——直接把文件交给签名工具，不复制、不走剪贴板。
struct PackageEntryCard: View {
    @Environment(AppEnvironment.self) private var environment
    let entry: CacheStore.Entry

    var body: some View {
        GlassSurface(level: .card, cornerRadius: Metrics.radiusL) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "app.badge.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(accent.gradient, in: .rect(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    ShareLink(item: fileURL) {
                        Label("导入到签名工具", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(accent.primary, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(PressableStyle())

                    Button("删除", systemImage: "trash", role: .destructive) {
                        environment.cache.remove(entry.id)
                    }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(StatusTone.failed)
                    .frame(width: 42, height: 42)
                    .background(StatusTone.failed.opacity(0.12), in: .rect(cornerRadius: 12))
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("删除 \(entry.name)")
                }
            }
            .padding(14)
        }
    }

    private var fileURL: URL {
        environment.cache.url(for: entry.id) ?? URL(fileURLWithPath: "/dev/null")
    }

    private var detail: String {
        let size = ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
        return "\(size) · \(RelativeTime.text(for: entry.savedAt))下载"
    }
}
