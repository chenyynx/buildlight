import SwiftUI

/// 背景：一层强调色柔光 + 一层右上角高光，全静态。
/// 玻璃需要背后有东西可折射，否则看起来只是一块灰白。
struct AccentBackdrop: View {
    @Environment(\.accent) private var accent
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: accent.wash, location: 0),
                    .init(color: accent.primary.opacity(0.03), location: 0.32),
                    .init(color: .clear, location: 0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.white.opacity(0.5), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 360
            )
            .blendMode(.plusLighter)
            .opacity(scheme == .dark ? 0.18 : 0.35)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
