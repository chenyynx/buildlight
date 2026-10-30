import Foundation
import WidgetKit
import WidgetKit

/// 主屏小组件用的数据快照。
///
/// 组件进程和 App 是两个进程，SwiftData 拿不到（也没有 App Group 权限——
/// 自签包没有 entitlement），所以用 `App Group` 之外的兜底方案：
/// App 每次刷新后把最近状态写成 JSON 放在**共享容器**里。
/// 没有 App Group 时退回 `UserDefaults(suiteName:)`，自签环境同样可用。
struct BuildWidgetEntry: TimelineEntry, Codable {
    let date: Date
    let runningCount: Int
    let failedCount: Int
    let items: [BuildWidgetItem]

    static let placeholder = BuildWidgetEntry(
        date: .now,
        runningCount: 1,
        failedCount: 0,
        items: [
            BuildWidgetItem(repo: "buildlight", branch: "main", isRunning: true, isFailed: false, when: "刚刚"),
            BuildWidgetItem(repo: "Agents-Anywhere", branch: "feat/ui", isRunning: false, isFailed: true, when: "12 分钟前"),
            BuildWidgetItem(repo: "wb2api-ios", branch: "main", isRunning: false, isFailed: false, when: "1 小时前")
        ]
    )
}

struct BuildWidgetItem: Codable, Identifiable, Hashable, Sendable {
    var id: String { repo }
    let repo: String
    let branch: String
    let isRunning: Bool
    let isFailed: Bool
    let when: String
}

/// App 与组件共享的那份快照。
enum BuildWidgetStore {
    /// 没有 App Group 时的兜底 suite 名。
    static let suiteName = "group.org.example.buildlight"
    private static let key = "widget.snapshot"

    static func save(_ entry: BuildWidgetEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> BuildWidgetEntry? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BuildWidgetEntry.self, from: data)
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
