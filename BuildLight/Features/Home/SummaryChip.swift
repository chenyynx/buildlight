import SwiftUI

/// 摘要胶囊。用半透明色块而不是实时玻璃——它跟着列表一起滚动，
/// 逐帧采样模糊会直接吃掉滚动的帧率。
struct SummaryChip: View {
    let title: String
    let systemImage: String
    /// 状态点颜色。有颜色 = 这个数字代表一个状态；没有 = 纯统计。
    var tint: Color? = nil
    /// 正在发生的状态用呼吸点，静态统计用圆点。
    var animated: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let tint {
                if animated {
                    PulsingDot(color: tint, size: 5)
                } else {
                    Circle().fill(tint).frame(width: 6, height: 6)
                }
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.4), in: .capsule)
    }
}
