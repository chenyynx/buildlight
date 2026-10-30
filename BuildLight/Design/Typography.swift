import SwiftUI
import UIKit

/// 排版 token。
///
/// **为什么不用 `.system(size:)` 硬编码字号**：
/// 固定字号不响应「设置 → 显示与亮度 → 文字大小」，
/// 把系统字体调大的用户在这个 App 里看到的永远是小字。
/// 这里统一用语义字号（`.subheadline` 等）+ 相对字重，
/// 系统会自动按用户的 Dynamic Type 缩放。
///
/// 数字类仍然保留 `monospacedDigit()`，避免计时器跳动时左右抖。
enum Type {
    /// 面板主标题
    static var headline: Font { .title3.weight(.bold) }
    /// 卡片标题
    static var cardTitle: Font { .subheadline.weight(.semibold) }
    /// 正文
    static var body: Font { .subheadline }
    /// 次要说明
    static var label: Font { .footnote }
    /// 元信息（工作流、分支、时间）
    static var caption: Font { .caption }
    /// 分组标题（小号 + 宽字距）
    static var section: Font { .caption.weight(.semibold) }

    /// Dynamic Type 放大系数。
    ///
    /// 用查表而不是 `UIFontMetrics.scaledValue(for:)`：
    /// 后者依赖 `UITraitCollection.current`，在 SwiftUI 的 body 求值里
    /// 这个值并不总是当前视图的档位，会算出错误的像素。
    /// 查表以 `.large` 为 1.0，数值对齐 Apple 的 Body 文本样式曲线。
    static func scaleFactor(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall: 0.82
        case .small: 0.88
        case .medium: 0.94
        case .large: 1.0
        case .xLarge: 1.12
        case .xxLarge: 1.23
        case .xxxLarge: 1.35
        case .accessibility1: 1.62
        case .accessibility2: 1.90
        case .accessibility3: 2.18
        case .accessibility4: 2.45
        case .accessibility5: 2.72
        @unknown default: 1.0
        }
    }
}

/// 按 Dynamic Type 缩放的字号修饰器。
///
/// 设计稿上的 15pt / 12pt 是「默认档位下」的视觉尺寸。
/// 直接写 `.font(.system(size:))` 时，用户把系统字体调大，这些字一动不动。
/// 换成这个修饰器后，默认档位视觉完全一致，放大档位会跟着放大。
extension View {
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(ScaledFontModifier(
            size: size,
            weight: weight,
            design: design,
            textStyle: textStyle
        ))
    }
}

private struct ScaledFontModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let textStyle: Font.TextStyle

    func body(content: Content) -> some View {
        content.font(
            .system(
                size: size * Type.scaleFactor(for: dynamicTypeSize),
                weight: weight,
                design: design
            )
        )
    }
}
