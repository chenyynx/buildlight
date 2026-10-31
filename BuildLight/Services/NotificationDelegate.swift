import Foundation
import UserNotifications

/// 通知点击的接收者。
///
/// **必须由 App 在 init 阶段设置**（不能放 `.task`）：
/// 从通知冷启动时，系统会在 Scene 建立前就投递 response，
/// 那时 `.task` 还没执行，委托没挂上就直接丢了这次点击。
///
/// 这里只负责把「要打开什么」写成意图，具体怎么找数据、怎么跳转，
/// 交给 `DeepLinkRouter` + 根视图处理。
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// 前台也显示横幅：构建结束/包就绪时用户多半正停在 App 里，
    /// 不显示的话只剩列表里一个数字变化，很容易错过。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        // 两种通知的载荷不完全一样：构建完成带 runID，安装包就绪也带；
        // 老版本发出去的可能只有仓库名——那种情况下退回到仓库的最新一条，
        // 总之不能「点开就停在原地」。
        let runID = info["runID"] as? Int
        let repo = info["repo"] as? String
        guard runID != nil || repo != nil else { return }
        await MainActor.run {
            DeepLinkRouter.shared.open(runID: runID, repoFullName: repo)
        }
    }
}
