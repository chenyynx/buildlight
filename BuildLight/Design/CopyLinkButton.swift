import SwiftUI
import UIKit

/// 复制链接的按钮：点了变勾、给触感，1.5 秒后复原。
///
/// 复制这种动作最讨厌的是「不知道成没成」，
/// 所以要有即时反馈——不只是触感，按钮本身也要变。
struct CopyLinkButton: View {
    let url: URL
    var title: String = "复制下载直链"
    var compact: Bool = false

    @Environment(\.accent) private var accent
    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 6) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                if !compact {
                    Text(copied ? "已复制" : title)
                        .scaledFont(size: 14)
                }
            }
            .foregroundStyle(copied ? StatusTone.success : accent.primary)
            .frame(maxWidth: compact ? nil : .infinity)
            .frame(height: compact ? 32 : 40)
            .padding(.horizontal, compact ? 10 : 0)
            .background(
                (copied ? StatusTone.success : accent.primary).opacity(0.10),
                in: .rect(cornerRadius: compact ? 9 : 12)
            )
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.success, trigger: copied) { _, new in new }
        .accessibilityLabel(copied ? "已复制链接" : title)
        .onDisappear { resetTask?.cancel() }
    }

    private func copy() {
        UIPasteboard.general.string = url.absoluteString
        copied = true

        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}
