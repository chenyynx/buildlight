import SwiftUI

/// 极缓慢流动的 Mesh 渐变，给纯色底加一点温度。
/// 明暗两套都只是把背景色和暖色微微拉开，不抢内容。
struct AnimatedBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: reduceMotion)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(width: 3, height: 3, points: points(phase), colors: colors)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func points(_ time: TimeInterval) -> [SIMD2<Float>] {
        let x = Float(sin(time * 0.23)) * 0.06
        let y = Float(cos(time * 0.19)) * 0.06
        let z = Float(sin(time * 0.15)) * 0.05
        return [
            [0, 0], [0.5 + x, 0], [1, 0],
            [0, 0.5 + y], [0.5 + x, 0.5 + y], [1, 0.5 + z],
            [0, 1], [0.5 + z, 1], [1, 1]
        ]
    }

    private var colors: [Color] {
        if colorScheme == .dark {
            return [
                Color(hex: 0x000000), Color(hex: 0x0B0607), Color(hex: 0x000000),
                Color(hex: 0x120C0A), Color(hex: 0x1A1013), Color(hex: 0x0A0708),
                Color(hex: 0x000000), Color(hex: 0x0D0809), Color(hex: 0x000000)
            ]
        }
        return [
            Color(hex: 0xFAF8F5), Color(hex: 0xFDF1E9), Color(hex: 0xFAF8F5),
            Color(hex: 0xFDF0EE), Color(hex: 0xFCE9EC), Color(hex: 0xFBF3EC),
            Color(hex: 0xFAF8F5), Color(hex: 0xFDF1E9), Color(hex: 0xFAF8F5)
        ]
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
