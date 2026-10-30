import SwiftUI

/// 品牌色：只在交互元素上用（按钮、选中态、链接），不参与状态表达。
///
/// 强调色由用户在设置页切换，共七款；具体值在 `AccentTheme`。
/// 视图通过环境变量 `@Environment(\.accent)` 取当前值，
/// 不要直接引用 `Accent.primary` 这样的全局常量。
/// 状态色：直接用系统标准色，不手调色值。
///
/// 为什么要用系统色：
/// - 随系统外观、增强对比度、色彩滤镜自动适配
/// - 和系统控件（通知、设置里的红点）是同一个红，不会"两套红"
/// - 之前手调的琥珀 #B4691F / 砖红 #A63A2E 在深色模式下偏脏，也正是这个原因
///
/// 语义映射：
/// - 进行中 = `.orange`（系统橙，表示"正在发生"）
/// - 失败   = `.red`（系统红）
/// - 成功   = `.green`（只在需要明确肯定时用，列表里仍保持安静）
/// - 静默   = `.secondary`
enum StatusTone {
    static let running = Color.orange
    static let failed = Color.red
    static let success = Color.green
    static let idle = Color.secondary
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
