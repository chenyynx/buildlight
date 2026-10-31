import SwiftUI
import UserNotifications
import UIKit

/// 通知诊断。
///
/// 之前收不到通知是完全静默的：不知道是没授权、开关关了、
/// 进程被挂起、还是根本没检测到状态变化。
/// 这一页把这些状态摊开，用户能自己判断问题在哪。
struct NotificationDiagnosticsView: View {
    @Environment(AppEnvironment.self) private var environment
    @ObservedObject private var notifications = NotificationDiagnostics.shared

    var body: some View {
        List {
            Section("权限") {
                diagnosticRow(
                    "系统授权",
                    value: authorizationText,
                    ok: notifications.authorization == .authorized
                )
                diagnosticRow(
                    "App 内开关",
                    value: notifications.isEnabled ? "已开启" : "已关闭",
                    ok: notifications.isEnabled
                )
            }

            Section("最近一次") {
                if let at = notifications.lastDeliveredAt {
                    LabeledContent("送达时间", value: at.formatted(date: .abbreviated, time: .standard))
                    if let title = notifications.lastDeliveredTitle {
                        LabeledContent("内容", value: title)
                    }
                } else {
                    Text("还没有成功送达过通知")
                        .font(Type.caption)
                        .foregroundStyle(.secondary)
                }

                if let reason = notifications.lastSkipReason {
                    LabeledContent("上次被跳过的原因", value: reason)
                        .foregroundStyle(StatusTone.failed)
                }
            }

            Section("后台能力") {
                diagnosticRow(
                    "后台执行窗口",
                    value: BackgroundExecutionKeeper.shared.isHoldingWindow ? "持有中" : "未持有",
                    ok: BackgroundExecutionKeeper.shared.isHoldingWindow
                )
                LabeledContent(
                    "上次前台刷新",
                    value: environment.monitor.lastRefreshAt?.formatted(date: .abbreviated, time: .standard) ?? "—"
                )
            }

            Section {
                Button("发一条测试通知") {
                    Task { await sendTest() }
                }
            } footer: {
                Text("""
                自签包没有 APNs，收不到远程推送。本地通知只在 App 进程还活着时生效：\
                前台一定收得到，刚切到后台的几十秒内也收得到。\
                更久的等待由系统按自己的节奏调度，不保证时间点——\
                要「关掉 App 也能收」，需要服务器侧常驻监视器。
                """)
            }
        }
        .navigationTitle("通知诊断")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notifications.refresh() }
    }

    private func diagnosticRow(_ title: String, value: String, ok: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(ok ? .secondary : StatusTone.failed)
        }
    }

    private var authorizationText: String {
        switch notifications.authorization {
        case .authorized: "已授权"
        case .denied: "已拒绝"
        case .provisional: "临时授权"
        case .ephemeral: "临时授权"
        case .notDetermined: "未询问"
        @unknown default: "未知"
        }
    }

    private func sendTest() async {
        let event = BuildEvent(
            runID: 0,
            repo: "测试仓库",
            repoFullName: "test/repo",
            branch: "main",
            number: 0,
            conclusion: "success",
            duration: 65
        )
        await NotificationService.shared.notify(event)
        await notifications.refresh()
    }
}

/// 诊断数据的观察入口。
///
/// `NotificationService` 是单例但没走 environment，
/// 用一个轻量包装让 SwiftUI 能订阅它的状态。
@MainActor
final class NotificationDiagnostics: ObservableObject {
    static let shared = NotificationDiagnostics()

    @Published var authorization: UNAuthorizationStatus = .notDetermined
    @Published var isEnabled = true
    @Published var lastDeliveredAt: Date?
    @Published var lastDeliveredTitle: String?
    @Published var lastSkipReason: String?

    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorization = settings.authorizationStatus

        let service = NotificationService.shared
        await service.refreshStatus()
        isEnabled = service.isEnabled
        lastDeliveredAt = service.lastDeliveredAt
        lastDeliveredTitle = service.lastDeliveredTitle
        lastSkipReason = service.lastSkipReason
    }
}
