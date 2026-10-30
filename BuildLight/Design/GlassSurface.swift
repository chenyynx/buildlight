import SwiftUI

/// 液态玻璃表面。App 的统一容器语言。
///
/// 为什么用系统 `glassEffect` 而不是手搓毛玻璃：
/// 手搓的 `Material` 不随滚动实时折射、也不响应点击高亮，
/// 在 iOS 26 上会和系统控件（tab 栏、工具栏）明显不同层。
/// `.glassEffect` 是同一套渲染管线，浮在内容上时能折射背后的卡片。
///
/// **着色强度是这里最容易做错的地方**：
/// `Glass.tint` 不是「底色」，它是叠在玻璃上的染色。
/// 一旦超过 0.2 左右，卡片就会变成一块纯色板，所有正文对比度立刻垮掉。
/// 这里只给 0.06–0.12 的极轻染色——玻璃的质感来自它对背景的折射，
/// 不是来自颜色。
enum GlassLevel {
    case panel
    case card
    case chip

    var tintOpacity: Double {
        switch self {
        case .panel: 0.07
        case .card: 0.09
        case .chip: 0.14
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
        let shape: RoundedRectangle = .rect(cornerRadius: cornerRadius)
        let tinted = accent.primary.opacity(level.tintOpacity)

        Group {
            if reduceTransparency {
                // 用户要求降低透明度时退回实色，可读性优先于质感。
                content
                    .background(
                        scheme == .dark ? Color(white: 0.13) : Color(white: 0.99),
                        in: shape
                    )
                    .overlay {
                        shape.strokeBorder(tinted, lineWidth: 1)
                    }
            } else {
                content
                    .glassEffect(
                        interactive
                            ? Glass.regular.tint(tinted).interactive()
                            : Glass.regular.tint(tinted),
                        in: shape
                    )
            }
        }
    }
}

/// 玻璃上的细分隔线。玻璃本身没有边界线，靠一条发丝线拉开层次。
struct GlassHairline: View {
    var leading: CGFloat = 0

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Rectangle()
            .fill(scheme == .dark ? .white.opacity(0.12) : .black.opacity(0.08))
            .frame(height: 0.5)
            .padding(.leading, leading)
    }
}
