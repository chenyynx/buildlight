import Foundation
import UserNotifications

/// 构建事件的本机通知。
///
/// 自签包没有 `aps-environment`，收不到远程推送；这里用的是本地通知，
/// 只在 App 进程还活着时生效（前台、刚切后台）。真正的「关掉 App 也能收」
/// 要靠服务器侧常驻监视器。
@MainActor
final class NotificationService {
    static let shared = NotificationService()
    nonisolated static let storageKey = "notifyBuildEvents"

    private(set) var isAuthorized = false
    private(set) var isDenied = false

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.storageKey) as? Bool ?? true
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
            isDenied = false
        case .denied:
            isAuthorized = false
            isDenied = true
        default:
            isAuthorized = false
            isDenied = false
        }
    }

    /// 只在「开关开着、且还没问过」时弹系统授权框，避免每次启动都打扰。
    func prepareIfNeeded() async {
        await refreshStatus()
        guard isEnabled, !isAuthorized, !isDenied else { return }
        _ = await requestAuthorization()
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            await refreshStatus()
            return granted
        } catch {
            await refreshStatus()
            return false
        }
    }

    func notify(_ event: BuildEvent) async {
        guard isEnabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default
        content.threadIdentifier = "build-\(event.repo)"
        content.userInfo = ["runID": event.runID]

        let request = UNNotificationRequest(
            identifier: "run-\(event.runID)-\(event.conclusion)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

struct BuildEvent: Sendable {
    let runID: Int
    let repo: String
    let branch: String?
    let number: Int
    let conclusion: String
    let duration: TimeInterval?

    var isFailure: Bool {
        conclusion == "failure" || conclusion == "timed_out" || conclusion == "startup_failure"
    }

    var title: String {
        if isFailure { return "构建失败 · \(repo)" }
        if conclusion == "cancelled" { return "构建已取消 · \(repo)" }
        return "构建完成 · \(repo)"
    }

    var body: String {
        var parts: [String] = []
        if let branch, !branch.isEmpty { parts.append(branch) }
        parts.append("#\(number)")
        if let duration {
            let total = max(0, Int(duration))
            parts.append("\(total / 60):\(String(format: "%02d", total % 60))")
        }
        return parts.joined(separator: " · ")
    }
}
