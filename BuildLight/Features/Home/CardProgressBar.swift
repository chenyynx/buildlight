import SwiftUI

/// 卡片底部那条 3pt 进度线。用容器宽度算比例，不依赖 GeometryReader 的额外布局。
struct CardProgressBar: View {
    let ratio: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(ratio, 0), 1))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}
