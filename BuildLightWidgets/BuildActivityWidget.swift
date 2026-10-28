import ActivityKit
import SwiftUI
import WidgetKit

struct BuildActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BuildActivityAttributes.self) { context in
            LockScreenBuildView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(Palette.wine)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("构建", systemImage: "hammer.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.wine)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.running.count) 个")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(context.state.running.prefix(3)) { build in
                            HStack(spacing: 8) {
                                Text(build.repo)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text(timerInterval: build.startedAt...Date.distantFuture, countsDown: false)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Palette.wine)
                            }
                        }
                        if context.state.running.count > 3 {
                            Text("另有 \(context.state.running.count - 3) 个在跑")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                }
            } compactLeading: {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(Palette.wine)
            } compactTrailing: {
                Text("\(context.state.running.count)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.wine)
            } minimal: {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(Palette.wine)
            }
            .keylineTint(Palette.wine)
        }
    }
}

private struct LockScreenBuildView: View {
    let state: BuildActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.wine)
                Text("构建看板")
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 8)
                Text("进行中 \(state.running.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.wine)
            }

            ForEach(state.running.prefix(3)) { build in
                HStack(spacing: 8) {
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
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Palette.wine)
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
}

private enum Palette {
    /// 和 App 里的酒红强调色对齐。
    static let wine = Color(red: 0.76, green: 0.35, blue: 0.42)
}
