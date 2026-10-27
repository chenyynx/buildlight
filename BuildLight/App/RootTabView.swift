import SwiftUI

enum AppTab: Hashable {
    case builds
    case history
    case settings
}

/// 底部导航交给系统 TabView —— iOS 26 会自动渲染成浮动玻璃胶囊，
/// 并且自带滚动收起、手势与无障碍支持，不要自己画。
struct RootTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: AppTab = .builds

    var body: some View {
        TabView(selection: $selection) {
            Tab("构建", systemImage: "square.grid.2x2", value: AppTab.builds) {
                NavigationStack { HomeView() }
            }
            Tab("历史", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                NavigationStack { HistoryView() }
            }
            Tab("设置", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack { SettingsView() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
