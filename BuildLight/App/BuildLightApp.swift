import SwiftUI
import SwiftData
import UIKit

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
            await environment.session.refreshIdentityIfNeeded()
            await NotificationService.shared.prepareIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                guard environment.session.isSignedIn else { return }
                environment.monitor.start()
                    Task { await environment.monitor.refreshAll() }
            default:
                // 进后台不主动停轮询：系统挂起进程后循环自然停，醒着的那几十秒
                // 还能抓到构建完成并弹本地通知。
                break
            }
        }
    }
}
