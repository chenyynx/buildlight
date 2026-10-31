import SwiftData
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
                diagnosticRow(
                    "静音保活",
                    value: keepAliveText,
                    ok: BackgroundKeepAlive.shared.isKeepingAlive
                )

                if !BackgroundKeepAlive.shared.isKeepingAlive {
                    Text(keepAliveHint)
                        .font(Type.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LabeledContent(
                    "上次前台刷新",
                    value: environment.monitor.lastRefreshAt?.formatted(date: .abbreviated, time: .standard) ?? "—"
                )
            }

            Section("后台持续监控") {
                Toggle("构建在跑时保持活跃", isOn: keepAliveBinding)
                Text("开关在「设置 → 后台」里，这里也能直接改。")
                    .font(Type.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("发一条测试通知") {
                    Task { await sendTest() }
                }
            } footer: {
                Text("""
                自签包没有 APNs，收不到远程推送。\
                构建进行中时，「后台持续监控」会用一段听不见的静音音频\
                让系统认为 App 仍在工作，从而不在后台挂起进程——\
                这样构建结束的那一刻能检测到并弹出通知。\
                全部构建结束时保活会自动停止，不白耗电。\
                App 被手动划掉之后仍然收不到，那种情况需要服务器侧监视器。
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

    /// 静音保活的状态。带启动时间，能看出它是不是一直挂着。
    private var keepAliveText: String {
        guard BackgroundKeepAlive.shared.isKeepingAlive else {
            return BackgroundKeepAlive.isEnabled ? "待命中" : "已关闭"
        }
        guard let start = BackgroundKeepAlive.shared.startedAt else { return "运行中" }
        let seconds = Int(Date.now.timeIntervalSince(start))
        return "运行中 · \(seconds / 60)分\(seconds % 60)秒"
    }

    /// 「待命中」不是坏了：保活只在对的时机才启动。
    private var keepAliveHint: String {
        guard BackgroundKeepAlive.isEnabled else {
            return "已在「设置 → 后台 → 后台持续监控」里关闭。"
        }
        let running = (try? environment.context.fetchCount(
            FetchDescriptor<RepoRecord>(predicate: #Predicate { $0.activeRunCount > 0 })
        )) ?? 0

        if running == 0 {
            return "当前没有构建在跑，不占用后台。等有构建启动、并且你把 App 切到后台时才会开启。"
        }
        return "有 \(running) 个构建在跑。App 留在前台时不会开启；切到后台后会自动启动。"
    }

    private var keepAliveBinding: Binding<Bool> {
        Binding(
            get: { BackgroundKeepAlive.isEnabled },
            set: { UserDefaults.standard.set($0, forKey: BackgroundKeepAlive.storageKey) }
        )
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
