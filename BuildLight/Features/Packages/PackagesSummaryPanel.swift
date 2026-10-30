import SwiftUI

/// 产物页顶部的概览面板。
struct PackagesSummaryPanel: View {
    let count: Int
    let totalSize: String

    @Environment(\.accent) private var accent

    var body: some View {
        GlassSurface(level: .panel, cornerRadius: Metrics.radiusXL) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(accent.gradient, in: .rect(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 3) {
                    Text(count > 0 ? "\(count) 个安装包" : "还没有包")
                        .font(.system(size: 17, weight: .semibold))
                    Text("占用 \(totalSize)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .padding(.horizontal, DS.pad)
    }
}
