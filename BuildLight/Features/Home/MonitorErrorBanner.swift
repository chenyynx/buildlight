import SwiftUI

/// 顶部错误条。
///
/// 拉取失败时**必须让人知道**：限流、断网、Token 失效，
/// 三种情况用户该做的事完全不同，不能统一显示成「加载失败」。
/// 只在有错时出现，且只占一行，不打断浏览。
struct MonitorErrorBanner: View {
    let errors: [String: AppError]
    var onRetry: () -> Void = {}

    /// 取「最严重」的一条，而不是字典里随机那一条。
    /// 未授权 > 限流 > 断网 > 其他——用户能采取行动的顺序。
    private var representative: AppError? {
        errors.values.min { lhs, rhs in
            severity(lhs) < severity(rhs)
        }
    }

    private func severity(_ error: AppError) -> Int {
        switch error {
        case .unauthorized: 0
        case .rateLimited: 1
        case .offline: 2
        default: 3
        }
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
                    if errors.count > 1 {
                        Text("另有 \(errors.count - 1) 个仓库同样失败")
                            .font(Type.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 4)

                Button("重试", action: onRetry)
                    .font(Type.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(StatusTone.failed)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(StatusTone.failed.opacity(0.12), in: .capsule)
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
