import SwiftUI

/// 刷新结果反馈条。
///
/// 用户点刷新后需要立刻知道「成没成」：
/// - 成功 → 绿色对勾 + 「已刷新 · 刚刚」，1.6 秒后自动消失
/// - 失败 → 红色 + 失败原因，贴住不自动消失（让用户看清）
///
/// 只在手动刷新时出现；后台轮询不打扰。
struct RefreshToast: View {
    enum Outcome: Equatable {
        case success(updatedCount: Int)
        case failure(String)
    }

    let outcome: Outcome

    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)

            Text(message)
                .font(Type.label.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: .capsule)
        .overlay {
            Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 0.5)
        }
        .padding(.horizontal, DS.pad)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch outcome {
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch outcome {
        case .success: StatusTone.success
        case .failure: StatusTone.failed
        }
    }

    private var message: String {
        switch outcome {
        case .success(let count):
            count > 0 ? "已刷新 · \(count) 个仓库有更新" : "已刷新 · 没有变化"
        case .failure(let text):
            text
        }
    }
}
