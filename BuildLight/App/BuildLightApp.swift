import SwiftUI
import SwiftData

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

    var body: some View {
        Group {
            if environment.session.isSignedIn {
                RootTabView()
            } else {
                OnboardingView()
            }
        }
        .task {
            await environment.session.refreshIdentityIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                guard environment.session.isSignedIn else { return }
                environment.monitor.start()
                Task { await environment.monitor.refreshNow() }
            default:
                environment.monitor.stop()
            }
        }
    }
}
