import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case builds
    case packages
    case history
    case settings
}

/// 底部导航交给系统：iOS 26 会渲染成浮动玻璃胶囊，
/// 滚动时按 `.onScrollDown` 收起。不要自己画。
struct RootTabView: View {
    @Query private var runs: [RunRecord]
    @State private var selection: AppTab = .builds

    /// 点了通知要打开的那条记录。
    /// 用 sheet 而不是切 tab 再 push：从任何 tab、任何深度都能直接落到详情，返回时回到原位。
    @State private var deepLinkedRun: RunRecord?

    private var activeCount: Int {
        runs.count(where: { $0.isActive })
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("构建", systemImage: "square.grid.2x2", value: AppTab.builds) {
                HomeView()
            }
            .badge(activeCount)

            Tab("产物", systemImage: "shippingbox", value: AppTab.packages) {
                PackagesView()
            }

            Tab("历史", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                HistoryView()
            }

            Tab("设置", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .background(LiveActivitySync())
        .onChange(of: NotificationService.shared.pendingRunID) { _, runID in
            guard let runID,
                  let run = runs.first(where: { $0.id == runID })
            else { return }
            _ = NotificationService.shared.consumePendingRunID()
            deepLinkedRun = run
        }
        .sheet(item: $deepLinkedRun) { run in
            NavigationStack {
                RunDetailView(run: run)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { deepLinkedRun = nil }
                        }
                    }
            }
        }
    }
}
