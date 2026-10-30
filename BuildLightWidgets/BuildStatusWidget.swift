import SwiftUI
import WidgetKit

/// 主屏小组件：小号看「谁在跑」，中号看最近三条。
///
/// 锁屏有实时活动、桌面有小组件，是同一套数据的两个入口：
/// 锁屏回答「现在在跑什么」，桌面回答「离开 App 之后发生了什么」。
struct BuildStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BuildStatusWidget", provider: BuildWidgetProvider()) { entry in
            BuildWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("构建状态")
        .description("在桌面上看谁在跑、最近有没有失败。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BuildWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BuildWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BuildWidgetEntry) -> Void) {
        completion(BuildWidgetStore.load() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BuildWidgetEntry>) -> Void) {
        let entry = BuildWidgetStore.load() ?? .placeholder
        // 15 分钟一档：组件自己不会拿到推送，
        // App 每次刷新会主动 reload，这里只做兜底。
        let next = Date(timeIntervalSinceNow: 15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct BuildWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BuildWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall: small
        default: medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            Spacer(minLength: 0)

            Text("\(entry.runningCount)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(entry.runningCount > 0 ? Color.accentColor : .secondary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(entry.runningCount > 0 ? "个在跑" : "全部空闲")
                .font(.caption)
                .foregroundStyle(.secondary)

            if entry.failedCount > 0 {
                Label("\(entry.failedCount) 个失败", systemImage: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            ForEach(entry.items.prefix(3)) { item in
                HStack(spacing: 8) {
                    statusDot(item)
                    Text(item.repo)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(item.isRunning ? "构建中" : item.when)
                        .font(.caption2)
                        .foregroundStyle(item.isRunning ? Color.accentColor : .secondary)
                        .lineLimit(1)
                }
            }

            if entry.items.isEmpty {
                Text("还没有构建记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "hammer.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.accentColor)
            Text("构建看板")
                .font(.caption.weight(.semibold))
            Spacer(minLength: 0)
        }
    }

    private func statusDot(_ item: BuildWidgetItem) -> some View {
        Group {
            if item.isRunning {
                Circle().fill(Color.accentColor).frame(width: 6, height: 6)
            } else if item.isFailed {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
            } else {
                Circle().strokeBorder(.secondary.opacity(0.6), lineWidth: 1.2)
                    .frame(width: 7, height: 7)
            }
        }
        .frame(width: 10, height: 10)
    }
}
