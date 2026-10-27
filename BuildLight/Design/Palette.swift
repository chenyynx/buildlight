import SwiftUI

/// 参考图那套视觉：纯黑底、衬线标题、单一暖色。
/// 只描述颜色和字体，不参与任何控件形态——控件一律用系统原生。
struct Palette {
    let background: Color
    let surface: Color
    let hairline: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accentStart: Color
    let accentEnd: Color
    let failure: Color

    var accentGradient: LinearGradient {
        LinearGradient(colors: [accentStart, accentEnd], startPoint: .leading, endPoint: .trailing)
    }

    static let dark = Palette(
        background: .black,
        surface: Color(hex: 0x141416),
        hairline: Color.white.opacity(0.075),
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.54),
        textTertiary: Color.white.opacity(0.38),
        accentStart: Color(hex: 0xFF9A5A),
        accentEnd: Color(hex: 0xF04E6E),
        failure: Color(hex: 0xF04E6E)
    )

    static let light = Palette(
        background: Color(hex: 0xF4F2EE),
        surface: .white,
        hairline: Color.black.opacity(0.085),
        textPrimary: Color(hex: 0x14100C),
        textSecondary: Color(hex: 0x14100C).opacity(0.54),
        textTertiary: Color(hex: 0x14100C).opacity(0.38),
        accentStart: Color(hex: 0xF79A5C),
        accentEnd: Color(hex: 0xD8355A),
        failure: Color(hex: 0xD8355A)
    )

    static func resolve(_ scheme: ColorScheme) -> Palette {
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
    /// 衬线只给大标题，正文一律系统无衬线。
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

extension View {
    /// 把系统 List/Form 的底色换成参考图那套，控件形态仍然是原生的。
    func editorialBackground(_ palette: Palette) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(palette.background)
    }
}

/// 小号全大写宽字距标签。
struct MicroLabel: View {
    let text: String
    var color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}
