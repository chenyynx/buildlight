import Foundation
import Observation
import SwiftUI

/// 全局时钟。
///
/// 「3 分钟前」「更新于 刚刚」这类文案是**算出来的**，
/// 不是系统自己走的——不主动刷新就一直停在视图第一次渲染时的那一刻。
/// 用户看到的后果是：切回来半天，时间还是「刚刚」。
///
/// 这里用一个 15 秒一跳的共享时钟：读它的视图会自动重绘，
/// 但只重绘真正依赖时间的那些，不会让整屏每秒抖一次。
@MainActor
@Observable
final class AppClock {
    static let shared = AppClock()

    private(set) var now = Date.now

    @ObservationIgnored private var task: Task<Void, Never>?
    /// 相对时间最小粒度是分钟，15 秒足够，也不会显得跳。
    private let interval: TimeInterval = 15

    private init() {}

    func start() {
        guard task == nil else { return }
        now = .now
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self, !Task.isCancelled else { return }
                self.now = .now
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// 回前台立刻对齐一次，不用等下一个 15 秒。
    func tickNow() {
        now = .now
    }

    /// 设置页用来展示节拍是否在跑。
    var isTicking: Bool { task != nil }
}

/// 会自动更新的相对时间文本。
///
/// 语义上等价于 `Text(RelativeTime.text(for: date))`，
/// 区别是它订阅 `AppClock`，时间到了自己变。
struct RelativeTimeText: View {
    let date: Date
    var suffix: String = ""

    var body: some View {
        // 显式读取，让 SwiftUI 建立观察关系。
        let now = AppClock.shared.now
        Text(RelativeTime.text(for: date, now: now) + suffix)
    }
}
