import SwiftUI
import UIKit

/// 全 App 唯一强调色：酒红。除语义状态（成功/失败）外不引入第二种品牌色。
enum Accent {
    /// 取自 AccentColor 资源，跟随明暗自动切换。
    static let primary = Color.accentColor
    /// 淡底，用于标签、图标背景与顶部柔光。
    static let soft = Color.accentColor.opacity(0.12)

    static var gradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// 状态色只表达状态，不参与品牌。
///
/// 全 App 只有两个信号色：
/// - 正在跑 = 琥珀（和品牌酒红、失败红都拉开色相）
/// - 失败   = 砖红
/// 完成 → 中性。完成不需要颜色，它只需要「不打扰」。
enum StatusTone {
    static let running = dynamic(light: 0xC2703A, dark: 0xE8A063)
    static let failed = dynamic(light: 0xB23A2C, dark: 0xF0736A)
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
    /// 大号数字：圆体 + 等宽数字，避免跳动。
    static func metric(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .rounded).monospacedDigit().bold()
    }

    static func metricSmall() -> Font {
        .system(.title2, design: .rounded).monospacedDigit().bold()
    }

    /// 小标签：caption + 中等字重。
    static var tag: Font { .caption.weight(.medium) }
}

extension View {
    /// 卡片底：半透明色块 + 发丝描边。
    /// 刻意不用 `.glassEffect` / `.ultraThinMaterial`——每张卡都做实时模糊会拖垮滚动。
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

    /// 真正的液态玻璃，只留给少量、静止的元素（例如顶部摘要胶囊）。
    func glassInteractive(cornerRadius: CGFloat = Metrics.radiusM) -> some View {
        self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    }

    /// 列表卡片用的液态玻璃。开了系统「降低透明度」就退回磨砂，
    /// 这是用户自己选的省电/可读性偏好，尊重它比强行好看重要。
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = Metrics.radiusL, reduceTransparency: Bool) -> some View {
        if reduceTransparency {
            self
                .background(.regularMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                }
        } else {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
    }
}
