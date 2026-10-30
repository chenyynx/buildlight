import SwiftUI

/// App 与锁屏组件共用的状态色。
///
/// 和 App 内 `StatusTone` 保持同一套语义：橙=进行中、红=失败、绿=就绪。
/// 组件进程里拿不到 App 的设计系统，所以这里放一份共享常量，
/// 两边都引用它，避免锁屏和 App 里出现「两种橙」。
enum BuildLightPalette {
    static let running = Color.orange
    static let failed = Color.red
    static let success = Color.green
    static let idle = Color.secondary
}
