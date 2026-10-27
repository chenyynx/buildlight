import SwiftUI

@main
struct BuildLightApp: App {
    @State private var store = BuildStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(nil)
        }
    }
}

struct RootView: View {
    @Environment(BuildStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.token == nil {
                TokenSetupView()
            } else {
                HomeView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if store.token != nil { store.startPolling() }
            default:
                store.stopPolling()
            }
        }
    }
}
