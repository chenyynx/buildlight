import SwiftUI
import UserNotifications

/// 通知点击的接收者。
///
/// 之前只在通知里写了 `userInfo["runID"]`，但没人接——
/// 用户点「构建失败」的通知，得到的是 App 首页，还得自己找那条记录。
/// 这里把点按翻译成 `NotificationService.pendingRunID`，
/// 由根视图负责跳转。
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// 前台也显示横幅：构建完成时用户多半正停在 App 里，
    /// 不显示的话就只剩列表里的一个数字变化，容易错过。
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
        let userInfo = response.notification.request.content.userInfo
        guard let runID = userInfo["runID"] as? Int else { return }
        await MainActor.run {
            NotificationService.shared.pendingRunID = runID
        }
    }
}
