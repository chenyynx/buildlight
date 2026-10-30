import SwiftUI

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
    /// 页面大标题（如「构建」用系统 large title，这里给页内标题）
    static var display: Font { .title2.weight(.bold) }
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

    /// 大数字。用相对字号，跟随 Dynamic Type 缩放。
    static func metric(_ style: Font.TextStyle = .title2, weight: Font.Weight = .semibold) -> Font {
        .system(style, weight: weight).monospacedDigit()
    }
}
