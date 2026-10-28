import SwiftUI

/// 设置行左侧的小图标：圆角方块 + 强调色，和系统设置一致。
struct SettingGlyph: View {
    let systemImage: String
    var tint: Color = Accent.primary

    var body: some View {
        Image(systemName: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(tint, in: .rect(cornerRadius: 7))
            .accessibilityHidden(true)
    }
}
