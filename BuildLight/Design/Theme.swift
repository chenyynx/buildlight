import SwiftUI

/// 状态色。
///
/// **「进行中」跟随强调色**：它是 App 里最常驻的状态（呼吸点、计时数字、
/// 卡片底边的光带），用一个固定的橙色会和用户选的强调色长期打架——
/// 选靛蓝时橙点显得脏，选湖蓝时又像两种品牌色。
/// 进行中本身就是「主交互状态」，用强调色是语义上最正确的选择。
///
/// 失败 / 就绪仍然是系统语义色：
/// - 失败 = `.red`，就绪 = `.green`
/// 它们与强调色无关，因为「出事了」和「可以装了」必须永远同一个颜色。
///
/// 用法：视图里用 `StatusTone.running(accent)`，不要写死颜色。
enum StatusTone {
    static let failed = Color.red
    static let success = Color.green
    static let idle = Color.secondary

    /// 进行中的颜色 = 当前强调色。
    static func running(_ accent: Accent) -> Color {
        accent.primary
    }
}

enum Metrics {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let minTap: CGFloat = 44

    static let radiusS: CGFloat = 10
    static let radiusM: CGFloat = 16
    static let radiusL: CGFloat = 22
    static let radiusXL: CGFloat = 28

    /// 悬浮 tab 栏下方留白，避免最后一行被盖住。
    static let tabBarClearance: CGFloat = 124
}

extension Font {
    static func metric(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .rounded).monospacedDigit().bold()
    }

    static func metricSmall() -> Font {
        .system(.title2, design: .rounded).monospacedDigit().bold()
    }

    static var tag: Font { .caption.weight(.medium) }
}

/// 屏幕底色：浅色是暖白，深色是近黑。整屏一层，不叠卡片。
struct PaperBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accent) private var accent

    var body: some View {
        ZStack {
            (scheme == .dark
                ? Color(red: 0.045, green: 0.045, blue: 0.05)
                : Color(red: 0.972, green: 0.961, blue: 0.945))
                .ignoresSafeArea()

            // 强调色晕：玻璃要折射出东西，背后得有东西。
            RadialGradient(
                colors: [accent.wash, .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 520
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

/// 行按压反馈：轻微缩放 + 变暗，比默认高亮更像「按下去」。
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : Motion.press, value: configuration.isPressed)
    }
}
