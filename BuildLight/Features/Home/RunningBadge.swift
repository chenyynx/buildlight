import SwiftUI

/// 运行中标记：填充强调色的胶囊 + 呼吸点。
/// 卡片上唯一有颜色的元素，扫一眼就能找到正在跑的那几张。
struct RunningBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.white)
                .frame(width: 5, height: 5)
            Text("运行中")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Accent.primary, in: .capsule)
    }
}
