import SwiftUI

/// 与 WorkBuddy 一致：顶部一层强调色柔光，向下淡出到纯背景色。
/// 静态绘制，没有任何逐帧动画——滚动时才不会掉帧。
struct AccentBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [Accent.soft.opacity(0.9), .clear],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }
}
