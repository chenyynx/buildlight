import SwiftUI

/// 液态玻璃表面。App 的统一容器语言。
///
/// 为什么用系统 `glassEffect` 而不是手搓毛玻璃：
/// 手搓的 `Material` 不随滚动实时折射、也不响应点击高亮，
/// 在 iOS 26 上会和系统控件（tab 栏、工具栏）明显不同层。
/// `.glassEffect` 是同一套渲染管线，浮在内容上时能折射背后的卡片。
///
/// 三档：
/// - `.panel`  内容区大面板，卡片背后的底板
/// - `.card`   仓库卡片
/// - `.chip`   小胶囊（状态标签、筛选条）
enum GlassLevel {
    case panel
    case card
    case chip

    var tintOpacity: Double {
        switch self {
        case .panel: 0.55
        case .card: 0.7
        case .chip: 0.9
        }
    }
}

/// 一块玻璃。内容在玻璃之上，文字永远清晰。
struct GlassSurface<Content: View>: View {
    let level: GlassLevel
    var cornerRadius: CGFloat = Metrics.radiusL
    var interactive: Bool = false
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accent) private var accent

    var body: some View {
        let style = Glass.regular.tint(accent.primary.opacity(level.tintOpacity))
        let shape: RoundedRectangle = .rect(cornerRadius: cornerRadius)

        Group {
            if reduceTransparency {
                // 用户要求降低透明度时退回实色，玻璃的可读性优先于质感。
                content
                    .background(
                        scheme == .dark
                            ? Color(white: 0.13)
                            : Color(white: 0.99),
                        in: shape
                    )
            } else {
                content
                    .glassEffect(interactive ? style.interactive() : style, in: shape)
            }
        }
    }
}

/// 玻璃上的细分隔线。玻璃本身没有边界线，靠一条发丝线拉开层次。
struct GlassHairline: View {
    var leading: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.14))
            .frame(height: 0.5)
            .padding(.leading, leading)
    }
}
