import SwiftUI

/// 强调色选择器。七款色等分一行。
///
/// **布局约束（踩过的坑）**：七个 44pt 的点击区 + 间距会超过 393pt 屏幕宽，
/// 一旦超宽，外层 `ScrollView` 的 VStack 会被整体撑开、左右被裁掉，
/// 看起来就像"卡片贴边、标题被切"。
/// 所以每个色点用 `frame(maxWidth: .infinity)` 平分可用宽度，
/// 点击区保证 44pt 高，宽度自适应。
struct AccentThemePicker: View {
    @Binding var selection: AccentTheme

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 2) {
                ForEach(AccentTheme.allCases) { theme in
                    swatch(theme)
                        .frame(maxWidth: .infinity)
                }
            }

            Text("强调色同时用于「进行中」的呼吸点、计时和进度光带。失败和可安装始终用系统红 / 绿。")
                .scaledFont(size: 11.5)
                .foregroundStyle(.secondary)
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
                    .frame(width: 28, height: 28)
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1)
                    }

                if isSelected {
                    Image(systemName: "checkmark")
                        .scaledFont(size: 12, weight: .black)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44)
            .overlay {
                if isSelected {
                    Circle()
                        .strokeBorder(color.opacity(0.55), lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
            }
            .scaleEffect(isSelected ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
