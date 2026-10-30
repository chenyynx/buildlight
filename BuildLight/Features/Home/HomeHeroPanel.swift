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
                            .font(.system(size: 21, weight: .bold))
                            .tracking(-0.4)
                            .foregroundStyle(.primary)
                        Text(subheadline)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    PulseBadge(count: runningCount)
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

/// 在跑数量的小徽标。没有在跑的时候整体变灰，不抢注意力。
struct PulseBadge: View {
    let count: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 5) {
            if count > 0 {
                Circle()
                    .fill(StatusTone.running)
                    .frame(width: 6, height: 6)
                    .scaleEffect(pulsing && !reduceMotion ? 1.35 : 1)
                    .opacity(pulsing && !reduceMotion ? 0.55 : 1)
            }
            Text("\(count)")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(count > 0 ? .primary : .tertiary)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(.quaternary.opacity(0.4), in: .capsule)
        .onAppear {
            guard count > 0, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .accessibilityLabel("\(count) 个构建进行中")
    }
}
