import SwiftUI

/// 首页顶部的「现在」面板。
///
/// 一屏之内回答三个问题：有没有包可以装、有几个在跑、上次更新是什么时候。
/// 玻璃面板浮在内容之上，背后的强调色晕会透过玻璃被折射出来。
struct HomeHeroPanel: View {
    let readyCount: Int
    let runningCount: Int
    let failedCount: Int
    let totalCount: Int
    let lastRefresh: Date?

    @Environment(\.accent) private var accent

    var body: some View {
        GlassSurface(level: .panel, cornerRadius: Metrics.radiusXL) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(headline)
                            .font(Type.headline)
                            .tracking(-0.4)
                            .foregroundStyle(.primary)
                        Text(subheadline)
                            .font(Type.label)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 0) {
                    MetricCell(value: "\(readyCount)", label: "可安装", tint: readyCount > 0 ? accent.primary : nil)
                    VerticalRule()
                    MetricCell(value: "\(runningCount)", label: "在跑", tint: runningCount > 0 ? StatusTone.running : nil)
                    VerticalRule()
                    MetricCell(value: "\(failedCount)", label: "失败", tint: failedCount > 0 ? StatusTone.failed : nil)
                    VerticalRule()
                    MetricCell(value: "\(totalCount)", label: "仓库")
                }
            }
            .padding(18)
        }
        .padding(.horizontal, DS.pad)
    }

    private var headline: String {
        if readyCount > 0 { return "有 \(readyCount) 个包可以装" }
        if runningCount > 0 { return "\(runningCount) 个仓库在构建" }
        if failedCount > 0 { return "有 \(failedCount) 个构建失败" }
        return "一切正常"
    }

    private var subheadline: String {
        if let lastRefresh {
            return "更新于 " + RelativeTime.text(for: lastRefresh)
        }
        return "尚未刷新"
    }
}

