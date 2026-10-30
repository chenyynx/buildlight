import SwiftUI

/// 强调色选择器。七款色，一行排开，选中项放大约 1.15 倍。
///
/// 选中态不只靠颜色——放大的圆点 + 外环 + 勾号，
/// 这样「不使用颜色区分」的用户也能分辨。
struct AccentThemePicker: View {
    @Binding var selection: AccentTheme

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach(AccentTheme.allCases) { theme in
                    swatch(theme)
                }
            }
            .frame(maxWidth: .infinity)

            Text("强调色只影响按钮、选中态和进度。构建状态永远用固定的琥珀（进行中）与砖红（失败）。")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func swatch(_ theme: AccentTheme) -> some View {
        let isSelected = theme == selection
        let color = theme.primary(for: scheme)

        return Button {
            withAnimation(Motion.settle) { selection = theme }
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44)
            .overlay {
                if isSelected {
                    Circle()
                        .strokeBorder(color.opacity(0.45), lineWidth: 2)
                        .frame(width: 38, height: 38)
                }
            }
            .scaleEffect(isSelected ? 1.12 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
