import Foundation
import Observation
import UserNotifications

/// 构建事件的本机通知。
///
/// 自签包没有 `aps-environment`，收不到远程推送；这里用的是本地通知，
/// 只在 App 进程还活着时生效（前台、刚切后台）。真正的「关掉 App 也能收」
/// 要靠服务器侧常驻监视器。
@MainActor
@Observable
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

    /// 安装包就绪通知。
    ///
    /// 和「构建完成」分开：包通常比整条 run 早几分钟生成，
    /// 这是用户真正在等的那个时刻。
    func notifyPackageReady(repo: String, name: String, sizeBytes: Int, runNumber: Int) async {
        guard isEnabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "安装包就绪 · \(repo)"
        var parts: [String] = []
        if runNumber > 0 { parts.append("#\(runNumber)") }
        parts.append(name)
        parts.append(ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file))
        content.body = parts.joined(separator: " · ")
        content.sound = .default
        content.threadIdentifier = "package-\(repo)"
        content.userInfo = ["repo": repo]

        let request = UNNotificationRequest(
            identifier: "package-\(repo)-\(name)-\(runNumber)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func notify(_ event: BuildEvent) async {
        guard isEnabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default
        content.threadIdentifier = "build-\(event.repoFullName)"
        // 带上仓库全名：冷启动时本地库还没有这条记录，
        // 只有 runID 的话没有任何接口能查出它属于哪个仓库。
        content.userInfo = [
            "runID": event.runID,
            "repo": event.repoFullName
        ]

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
    /// 展示用短名。
    let repo: String
    /// 完整 repo，通知点进去要靠它补拉数据。
    let repoFullName: String
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
