import SwiftUI

/// App 与锁屏组件共用的状态色。
///
/// 组件进程拿不到 App 的强调色环境，所以强调色由 App 在启动 Activity 时
/// 写进 `ContentState`（见 `BuildActivityAttributes`），这里只保留兜底色。
/// 兜底色用蓝紫色系，和 App 默认的靛蓝一致，
/// 不再用橙色——锁定屏上和用户选的强调色对不上会很突兀。
enum BuildLightPalette {
    static let fallbackAccent = Color(red: 0.23, green: 0.36, blue: 0.82)
    static let failed = Color.red
    static let success = Color.green
    static let idle = Color.secondary
}
