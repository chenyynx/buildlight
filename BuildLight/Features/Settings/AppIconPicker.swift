import SwiftUI
import UIKit

/// 主屏幕图标选择器。
///
/// 和「强调色」分开：强调色改的是 App 内部的按钮/进度，
/// 图标是主屏幕上第一眼看到的东西，两者不必绑定——
/// 有人喜欢靛蓝界面配玫瑰图标。
struct AppIconPicker: View {
    @Binding var selection: AppIconOption

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 2) {
                ForEach(AppIconOption.allCases) { option in
                    item(option)
                        .frame(maxWidth: .infinity)
                }
            }

            Text("只改主屏幕图标的外观，不影响界面配色。系统会弹一次确认提示。")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func item(_ option: AppIconOption) -> some View {
        let isSelected = option == selection
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        return Button {
            apply(option)
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if let swatch = option.swatch {
                        shape.fill(swatch.gradient)
                    } else {
                        // 原色：黑白各一半，暗示「跟随系统外观」
                        shape.fill(
                            LinearGradient(
                                colors: scheme == .dark
                                    ? [Color(white: 0.15), Color(white: 0.9)]
                                    : [Color(white: 0.98), Color(white: 0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(option == .default ? 0.85 : 0.95))
                }
                .frame(width: 34, height: 34)
                .overlay {
                    if isSelected {
                        shape.strokeBorder(.primary.opacity(0.55), lineWidth: 2)
                            .padding(-2)
                    }
                }
                .scaleEffect(isSelected ? 1.06 : 1)

                Text(option.title)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func apply(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else {
            selection = AppIconOption.current
            return
        }
        guard option != AppIconOption.current else {
            selection = option
            return
        }

        withAnimation(Motion.settle) { selection = option }
        UIApplication.shared.setAlternateIconName(option.alternateName) { error in
            guard error != nil else { return }
            // 失败时回到系统真实状态，不要留一个「选了但没生效」的假象。
            Task { @MainActor in
                selection = AppIconOption.current
            }
        }
    }
}
