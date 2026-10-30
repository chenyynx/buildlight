import SwiftUI
import UIKit

/// 品牌色：只在交互元素上用（按钮、选中态、链接），不参与状态表达。
enum Accent {
    static let primary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.85, green: 0.47, blue: 0.56, alpha: 1)
            : UIColor(red: 0.56, green: 0.18, blue: 0.25, alpha: 1)
    })
    static let soft = primary.opacity(0.12)

    static var gradient: LinearGradient {
        LinearGradient(colors: [primary, primary.opacity(0.7)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// 状态色：全 App 只有两个。
/// 正在跑 = 琥珀（和品牌酒红、失败红都拉开色相）；失败 = 砖红；完成 = 中性。
enum StatusTone {
    static let running = dynamic(light: 0xB4691F, dark: 0xE0A063)
    static let failed = dynamic(light: 0xA63A2E, dark: 0xF0736A)
    static let idle = dynamic(light: 0xB0AAA4, dark: 0x6E6A66)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
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
    static let tabBarClearance: CGFloat = 96
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

/// 纸张底色：浅色是暖白，深色是近黑。整屏一层，不叠卡片。
struct PaperBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        (scheme == .dark
            ? Color(red: 0.045, green: 0.045, blue: 0.05)
            : Color(red: 0.972, green: 0.961, blue: 0.945))
            .ignoresSafeArea()
    }
}

/// 行按压反馈：轻微缩放 + 变暗，比默认高亮更像「按下去」。
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func cardSurface(
        cornerRadius: CGFloat = Metrics.radiusL,
        fill: AnyShapeStyle = AnyShapeStyle(.quaternary.opacity(0.45))
    ) -> some View {
        self
            .background(fill, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
            }
    }
}
