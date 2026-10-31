import Foundation
import SwiftData
import UIKit

/// 后台执行窗口。
///
/// iOS 在 App 进入后台几秒后就会挂起进程。挂起 = 轮询停止 =
/// 构建结束时没有人发现，也就不会有任何通知。
///
/// 这里在「进后台且有构建在跑」时申请一个后台任务断言，
/// 把进程多留几十秒；期间继续轮询，能抓到刚刚结束的构建。
/// 断言到期（或被系统提前回收）就老实放手——
/// 更长的等待只能靠 `BGAppRefreshTask`，而那个由系统按自己的节奏调度，
/// 不保证时间点。
@MainActor
final class BackgroundExecutionKeeper {
    static let shared = BackgroundExecutionKeeper()

    private var assertion: UIBackgroundTaskIdentifier = .invalid
    private var loop: Task<Void, Never>?
    private weak var environment: AppEnvironment?

    /// 是否正持有后台执行窗口（供设置页诊断用）。
    private(set) var isHoldingWindow = false

    func attach(environment: AppEnvironment) {
        self.environment = environment
    }

    /// 进后台时调用。没有在跑的构建就不占用系统资源。
    func beginIfNeeded() {
        guard let environment, assertion == .invalid else { return }

        let active = (try? environment.context.fetch(
            FetchDescriptor<RepoRecord>(predicate: #Predicate { $0.activeRunCount > 0 })
        )) ?? []
        guard !active.isEmpty else { return }

        assertion = UIApplication.shared.beginBackgroundTask(withName: "buildlight.poll") {
            // 系统要收回：立刻收尾，否则会被强杀。
            Task { @MainActor in BackgroundExecutionKeeper.shared.end() }
        }

        guard assertion != .invalid else { return }
        isHoldingWindow = true

        loop = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await environment.monitor.refreshAll()

                // 全部跑完就没必要继续占着窗口。
                let stillActive = (try? environment.context.fetch(
                    FetchDescriptor<RepoRecord>(predicate: #Predicate { $0.activeRunCount > 0 })
                )) ?? []
                if stillActive.isEmpty { break }

                try? await Task.sleep(for: .seconds(5))
            }
            self.end()
        }
    }

    /// 回前台或窗口到期时调用。
    func end() {
        loop?.cancel()
        loop = nil

        guard assertion != .invalid else { return }
        UIApplication.shared.endBackgroundTask(assertion)
        assertion = .invalid
        isHoldingWindow = false
    }
}
