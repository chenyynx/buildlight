import SwiftData
import SwiftUI

/// 首页：产物优先的双层结构。
///
/// 第一层（吸顶面板 + 「可安装」区）回答「现在能装什么」；
/// 第二层（其余仓库）回答「还有什么在动」。
///
/// 相比旧版把 19 个仓库平铺成列表，这样用户滚不到一半就能拿到包。
struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    @State private var searchText = ""
    @State private var filter: RepoFilter = .all
    @State private var isSyncing = false
    @State private var toast: RefreshToast.Outcome?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HomeHeroPanel(
                        readyCount: sections.actionable.count,
                        runningCount: sections.running.count,
                        failedCount: failingCount,
                        totalCount: visibleRepos.count,
                        lastRefresh: environment.monitor.lastRefreshAt
                    )
                    .padding(.top, 4)

                    if let toast {
                        RefreshToast(outcome: toast)
                            .padding(.top, 10)
                    }

                    MonitorErrorBanner(errors: environment.monitor.errors)

                    filterBar

                    if sections.isEmpty {
                        ContentUnavailableView {
                            Label("没有匹配的仓库", systemImage: "shippingbox")
                        } description: {
                            Text(searchText.isEmpty ? "下拉刷新试试" : "换个关键词")
                        }
                        .padding(.top, 48)
                    }

                    cardGroups
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, Metrics.tabBarClearance)
            }
            .scrollIndicators(.hidden)
            .background(PaperBackground())
            .navigationTitle("构建")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索仓库")
            .refreshable {
                let changed = await refresh()
                show(.success(updatedCount: changed))
            }
            .animation(Motion.settle, value: toast)
            .sensoryFeedback(.success, trigger: toast) { _, new in
                if case .some(.success) = new { return true }
                return false
            }
            .sensoryFeedback(.warning, trigger: toast) { _, new in
                if case .some(.failure) = new { return true }
                return false
            }
            .navigationDestination(for: String.self) { fullName in
                if let repo = repos.first(where: { $0.fullName == fullName }) {
                    RepoDetailView(repo: repo)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await sync() }
                    } label: {
                        if isSyncing || environment.monitor.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isSyncing)
                    .accessibilityLabel("同步仓库")
                }
            }
        }
    }

    // MARK: 分组

    @ViewBuilder
    private var cardGroups: some View {
        if !sections.actionable.isEmpty {
            SectionLabel("可安装", trailing: "\(sections.actionable.count)")
            ForEach(sections.actionable) { section in
                card(section)
            }
        }

        if !sections.running.isEmpty {
            SectionLabel("正在构建", trailing: "\(sections.running.count)")
            ForEach(sections.running) { section in
                card(section)
            }
        }

        if !sections.idle.isEmpty {
            SectionLabel(
                sections.actionable.isEmpty && sections.running.isEmpty ? "全部仓库" : "其余仓库",
                trailing: "\(sections.idle.count)"
            )
            ForEach(sections.idle) { section in
                card(section)
            }
        }
    }

    private func card(_ section: HomeSection) -> some View {
        NavigationLink(value: section.repo.fullName) {
            RepoCardContainer(repo: section.repo) {
                RepoCard(repo: section.repo)
            }
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, DS.pad)
        .padding(.bottom, 10)
    }

    // MARK: 筛选

    private var filterBar: some View {
        Picker("筛选", selection: $filter) {
            ForEach(RepoFilter.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DS.pad)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: 数据

    private var visibleRepos: [RepoRecord] {
        repos.filter { !$0.isHidden }
    }

    private var filteredRepos: [RepoRecord] {
        visibleRepos.filter { repo in
            let matchesSearch = searchText.isEmpty
                || repo.displayName.localizedStandardContains(searchText)
                || repo.fullName.localizedStandardContains(searchText)
            guard matchesSearch else { return false }

            switch filter {
            case .all: return true
            case .running: return repo.isRunning
            case .failing: return repo.latestFailed
            }
        }
    }

    private var sections: HomeSections {
        HomeSections.make(from: filteredRepos) { repo in
            guard let id = repo.packageID else { return false }
            if case .ready = environment.packages.state(for: id) { return true }
            return false
        }
    }

    private var failingCount: Int {
        visibleRepos.count(where: { $0.latestFailed })
    }

    // MARK: 行为

    private func sync() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await environment.repos.syncAll()
        } catch {
            show(.failure(AppError.map(error).localizedDescription))
            return
        }
        let changed = await refresh()
        show(.success(updatedCount: changed))
    }

    /// 刷新并返回「有多少仓库的数据发生了变化」。
    /// 用刷新前后的快照对比，比让监控层回调更省事，也不会多一层状态。
    @discardableResult
    private func refresh() async -> Int {
        let before = snapshot()
        await environment.monitor.refreshNow()
        let after = snapshot()
        return after.subtracting(before).count
    }

    private func snapshot() -> Set<String> {
        Set(visibleRepos.map {
            "\($0.fullName)#\($0.latestRunID ?? -1)#\($0.activeRunCount)#\($0.latestConclusionRaw ?? "")"
        })
    }

    /// 成功 1.8 秒后自动收起；失败常驻，让用户看清原因。
    private func show(_ outcome: RefreshToast.Outcome) {
        withAnimation(Motion.settle) { toast = outcome }
        guard case .success = outcome else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(Motion.settle) { toast = nil }
        }
    }
}
