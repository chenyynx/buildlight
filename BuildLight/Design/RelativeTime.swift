import Foundation

/// 中文相对时间。不要用 `.formatted(.relative)`——
/// 设备语言里带 en-CN 时会输出「2 hours ago」。
enum RelativeTime {
    static func text(for date: Date, now: Date = .now) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 0 { return "刚刚" }
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60)) 分钟前" }
        if seconds < 86_400 { return "\(Int(seconds / 3600)) 小时前" }
        if seconds < 172_800 { return "昨天" }
        if seconds < 2_592_000 { return "\(Int(seconds / 86_400)) 天前" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
