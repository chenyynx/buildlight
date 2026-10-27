import SwiftUI

/// 两套配色共用一套语义 token。深色是墨黑，浅色是纸白。
struct DesignPalette: Sendable {
    let background: Color
    let surface: Color
    let hairline: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accentStart: Color
    let accentEnd: Color
    let success: Color
    let failure: Color

    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentStart, accentEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static let dark = DesignPalette(
        background: .black,
        surface: Color(hex: 0x141416),
        hairline: Color.white.opacity(0.075),
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.54),
        textTertiary: Color.white.opacity(0.38),
        accentStart: Color(hex: 0xFF9A5A),
        accentEnd: Color(hex: 0xF04E6E),
        success: Color.white.opacity(0.55),
        failure: Color(hex: 0xF04E6E)
    )

    static let light = DesignPalette(
        background: Color(hex: 0xF4F2EE),
        surface: .white,
        hairline: Color.black.opacity(0.085),
        textPrimary: Color(hex: 0x14100C),
        textSecondary: Color(hex: 0x14100C).opacity(0.54),
        textTertiary: Color(hex: 0x14100C).opacity(0.38),
        accentStart: Color(hex: 0xF79A5C),
        accentEnd: Color(hex: 0xD8355A),
        success: Color(hex: 0x14100C).opacity(0.30),
        failure: Color(hex: 0xD8355A)
    )

    static func resolve(_ scheme: ColorScheme) -> DesignPalette {
        scheme == .dark ? .dark : .light
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension Font {
    /// 衬线只给标题用，正文一律无衬线。
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func metric(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

/// 小号全大写标签，编辑感的主要来源之一。
struct MicroLabel: View {
    let text: String
    var color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(color)
    }
}
