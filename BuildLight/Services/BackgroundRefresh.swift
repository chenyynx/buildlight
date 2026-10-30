import BackgroundTasks
import Foundation
import SwiftData

/// 后台刷新。
///
/// 自签包没有 APNs，App 被杀之后什么都收不到；
/// 但系统仍允许在合适的时机唤醒 App 做一次短刷新。
/// 这里注册一个最早的 15 分钟任务，只在「有仓库正在跑」时才真的联网，
/// 其余情况直接结束，避免白白耗电、也避免被系统降权。
@MainActor
final class BackgroundRefresh {
    static let shared = BackgroundRefresh()
    nonisolated static let taskIdentifier = "org.example.buildlight.refresh"

    private weak var environment: AppEnvironment?

    func register(environment: AppEnvironment) {
        self.environment = environment
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await self?.handle(refreshTask)
            }
        }
    }

    /// 进前台/进后台都可以调，重复调用无副作用。
    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(_ task: BGAppRefreshTask) async {
        // 先把下一次排上：任务只能排一个，不续排就再也不会触发。
        schedule()

        guard let environment else {
            task.setTaskCompleted(success: false)
            return
        }

        let work = Task { @MainActor in
            // 没有在跑的构建就什么都不做，省电也省配额。
            let active = (try? environment.context.fetch(
                FetchDescriptor<RepoRecord>(predicate: #Predicate { $0.activeRunCount > 0 })
            )) ?? []
            guard !active.isEmpty else { return }
            await environment.monitor.refreshAll()
        }

        task.expirationHandler = {
            work.cancel()
        }

        await work.value
        task.setTaskCompleted(success: !work.isCancelled)
    }
}
