import SwiftUI

struct ArtifactRow: View {
    let artifact: ArtifactRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    }

    private var subtitle: String {
        guard let expires = artifact.expiresAt else { return artifact.sizeText }
        let days = Calendar.current.dateComponents([.day], from: .now, to: expires).day ?? 0
        return days > 0
            ? "\(artifact.sizeText) · 剩 \(days) 天"
            : "\(artifact.sizeText) · 即将过期"
    }
}
