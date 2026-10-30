import SwiftUI
import SwiftData
import UserNotifications

@main
struct BuildLightApp: App {
    @State private var environment: AppEnvironment

    init() {
        let container: ModelContainer
        do {
            container = try PersistenceStack.makeContainer()
        } catch {
            // 本地库打不开时退化到内存，至少让 App 可用（数据不落盘）。
            container = try! PersistenceStack.makeContainer(inMemory: true)
        }
        _environment = State(initialValue: AppEnvironment(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .modelContainer(environment.container)
        }
    }
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme


    /// 当前生效的强调色。切主题时整个 App 立刻跟着变。
    private var accent: Accent {
        environment.appearance.accent(for: colorScheme)
    }

    var body: some View {
        Group {
            if !environment.session.isSignedIn {
                OnboardingView()
            } else {
                RootTabView()
            }
        }
        .tint(accent.primary)
        .environment(\.accent, accent)
        .environment(\.reducesMotion, environment.appearance.reduceMotionEnabled)
        .task {
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
            await environment.session.refreshIdentityIfNeeded()
            await NotificationService.shared.prepareIfNeeded()
            // 冷启动时 scenePhase 初始就是 .active，onChange 不会触发。
            // 不在这里补一次，第一次打开根本不会开始轮询。
            guard environment.session.isSignedIn else { return }
            environment.monitor.start()
            await environment.monitor.refreshAll()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, environment.session.isSignedIn else { return }
            environment.monitor.start()
            // 回前台立刻全量刷一遍：挂起期间数据是旧的，
            // 用户第一眼看到的必须是真实状态，而不是几秒前的快照。
            Task { await environment.monitor.refreshAll() }
        }
    }
}
