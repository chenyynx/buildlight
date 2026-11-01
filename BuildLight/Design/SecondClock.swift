import Foundation
import Observation
import SwiftUI

/// 秒级时钟，专门给「正在跑的构建」走秒用。
///
/// **为什么不用 `Text(timerInterval:)`**：
/// 它的刷新粒度是根据区间长度决定的。我们传的是
/// `start...Date.distantFuture`（几千年），系统据此认为不需要频繁刷新，
/// 结果就是数字**一直停在 0:00 不动**——这正是用户看到的现象。
///
/// **为什么不用 `TimelineView(.periodic)`**：它由 SwiftUI 调度驱动，
/// App 被挂起时调度会停，回前台后可能整段卡住。
///
/// 所以这里自己数：一个全局 1 秒任务，只有真正有计时器在屏幕上时才跑
/// （引用计数），没有在跑的构建就完全停掉，不白耗电。
@MainActor
@Observable
final class SecondClock {
    static let shared = SecondClock()

    private(set) var now = Date.now

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var users = 0

    private init() {}

    /// 视图出现时登记，最后一个视图消失时停表。
    func retain() {
        users += 1
        guard task == nil else { return }
        now = .now
        task = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else { return }
                self.now = .now
            }
        }
    }

    func release() {
        users = max(0, users - 1)
        guard users == 0 else { return }
        task?.cancel()
        task = nil
    }

    /// 回前台立刻对齐，不必等下一秒。
    func tickNow() {
        now = .now
    }

    var isRunning: Bool { task != nil }
}

/// 自动走秒的耗时文本，格式与 `RepoDurationText.clock` 一致（`分:秒`）。
struct ElapsedTimeText: View {
    let start: Date

    var body: some View {
        // 读到 now 就会订阅，每秒重建一次这个 Text。
        let now = SecondClock.shared.now
        Text(RepoDurationText.clock(from: start, to: now))
            .monospacedDigit()
            .onAppear { SecondClock.shared.retain() }
            .onDisappear { SecondClock.shared.release() }
    }
}
