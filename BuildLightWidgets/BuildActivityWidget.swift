import ActivityKit
import SwiftUI
import WidgetKit

/// 锁屏 / 灵动岛实时活动。
///
/// 设计原则与 App 内一致：
/// - 状态色用系统标准色（橙=进行中、红=失败），不手调
/// - 信息优先级：谁在跑 > 跑了多久 > 分支
/// - 锁屏是「扫一眼」的场景，一行一个仓库，不做卡片嵌套
struct BuildActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BuildActivityAttributes.self) { context in
            LockScreenBuildView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(BuildLightPalette.running)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("构建中", systemImage: "hammer.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BuildLightPalette.running)
                        .padding(.leading, 2)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    CountBadge(count: context.state.running.count)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(context.state.running.prefix(3)) { build in
                            IslandBuildRow(build: build)
                        }

                        if context.state.running.count > 3 {
                            Text("另有 \(context.state.running.count - 3) 个在跑")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }
            } compactLeading: {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(BuildLightPalette.running)
            } compactTrailing: {
                Text("\(context.state.running.count)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(BuildLightPalette.running)
            } minimal: {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(BuildLightPalette.running)
            }
            .keylineTint(BuildLightPalette.running)
        }
    }
}

// MARK: - 锁屏卡片

private struct LockScreenBuildView: View {
    let state: BuildActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            VStack(spacing: 8) {
                ForEach(state.running.prefix(3)) { build in
                    LockScreenBuildRow(build: build)
                }
            }

            if state.running.count > 3 {
                Text("另有 \(state.running.count - 3) 个在跑")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    private var header: some View {
        HStack(spacing: 6) {
            // 一个会呼吸的圆点，比静态图标更能说明「还在动」
            Circle()
                .fill(BuildLightPalette.running)
                .frame(width: 7, height: 7)

            Text("构建中")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            CountBadge(count: state.running.count)
        }
    }
}

private struct LockScreenBuildRow: View {
    let build: RunningBuild

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(build.repo)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if !build.branch.isEmpty {
                    Text(build.branch)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(timerInterval: build.startedAt...Date.distantFuture, countsDown: false)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(BuildLightPalette.running)
                .monospacedDigit()
        }
    }
}

private struct IslandBuildRow: View {
    let build: RunningBuild

    var body: some View {
        HStack(spacing: 8) {
            Text(build.repo)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(timerInterval: build.startedAt...Date.distantFuture, countsDown: false)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(BuildLightPalette.running)
                .monospacedDigit()
        }
    }
}

/// 数量胶囊。没有在跑时整体变灰，不抢注意力。
private struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(count > 0 ? BuildLightPalette.running : .secondary)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(.quaternary.opacity(0.5), in: .capsule)
    }
}
