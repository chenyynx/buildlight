import SwiftUI

/// 摘要胶囊。用半透明色块而不是实时玻璃——它跟着列表一起滚动，
/// 逐帧采样模糊会直接吃掉滚动的帧率。
struct SummaryChip: View {
    let title: String
    let systemImage: String
    let isProminent: Bool

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(isProminent ? AnyShapeStyle(Accent.primary) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.45), in: .capsule)
    }
}
