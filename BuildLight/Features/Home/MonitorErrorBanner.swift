import SwiftUI

/// 顶部错误条。
///
/// 拉取失败时**必须让人知道**：限流、断网、Token 失效，
/// 三种情况用户该做的事完全不同，不能统一显示成「加载失败」。
/// 只在有错时出现，且只占一行，不打断浏览。
struct MonitorErrorBanner: View {
    let errors: [String: AppError]

    private var representative: AppError? {
        errors.values.first
    }

    var body: some View {
        if let error = representative {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon(for: error))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(StatusTone.failed)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title(for: error))
                        .font(Type.label.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(error.localizedDescription)
                        .font(Type.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(StatusTone.failed.opacity(0.10), in: .rect(cornerRadius: Metrics.radiusM))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.radiusM)
                    .strokeBorder(StatusTone.failed.opacity(0.25), lineWidth: 0.5)
            }
            .padding(.horizontal, DS.pad)
            .padding(.top, 10)
            .accessibilityElement(children: .combine)
        }
    }

    private func title(for error: AppError) -> String {
        switch error {
        case .offline: "网络不可用"
        case .rateLimited: "接口限流"
        case .unauthorized: "登录已失效"
        case .notFound: "仓库不可访问"
        default: "刷新失败"
        }
    }

    private func icon(for error: AppError) -> String {
        switch error {
        case .offline: "wifi.slash"
        case .rateLimited: "hourglass"
        case .unauthorized: "key.slash"
        default: "exclamationmark.triangle.fill"
        }
    }
}
