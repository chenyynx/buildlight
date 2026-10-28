import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case builds
    case history
    case settings
}

/// 底部导航交给系统：iOS 26 会渲染成浮动玻璃胶囊，
/// 滚动时按 `.onScrollDown` 收起。不要自己画。
struct RootTabView: View {
    @Query private var runs: [RunRecord]
    @State private var selection: AppTab = .builds

    private var activeCount: Int {
        runs.filter(\.isActive).count
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("构建", systemImage: "square.grid.2x2", value: AppTab.builds) {
                HomeView()
            }
            .badge(activeCount)
            Tab("历史", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                HistoryView()
            }
            Tab("设置", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
