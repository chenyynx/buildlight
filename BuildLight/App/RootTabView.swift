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
    @Environment(AppEnvironment.self) private var environment
    @Query private var runs: [RunRecord]
    @State private var selection: AppTab = .builds

    /// 点了通知要打开的那条记录。
    /// 用 sheet 而不是切 tab 再 push：从任何 tab、任何深度都能直接落到详情，返回时回到原位。
    @State private var deepLinkedRun: RunRecord?
    @State private var deepLinkMissed = false

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
        .task(id: DeepLinkRouter.shared.pending) {
            await handleDeepLink()
        }
        .alert("找不到这次构建", isPresented: $deepLinkMissed) {
            Button("好") {}
        } message: {
            Text("这条记录可能已被清理，或者仓库已被移除。")
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

    /// 处理一次深链。
    ///
    /// 三步：本地找 → 找不到按 runID 从 API 补拉 → 都没有才提示。
    /// 之前这里只做第一步，冷启动时数据还没同步到，`guard` 直接 return，
    /// 点击就静默丢失了。
    private func handleDeepLink() async {
        guard let pending = DeepLinkRouter.shared.consume() else { return }

        if let run = runs.first(where: { $0.id == pending.runID }) {
            deepLinkedRun = run
            return
        }

        guard let fullName = pending.repoFullName else {
            deepLinkMissed = true
            return
        }

        if let fetched = await environment.monitor.ensureRun(
            repoFullName: fullName,
            runID: pending.runID
        ) {
            deepLinkedRun = fetched
        } else {
            deepLinkMissed = true
        }
    }
}
