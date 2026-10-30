import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    @State private var searchText = ""
    @State private var filter: RepoFilter = .all
    @State private var isSyncing = false

    var body: some View {
        let items = filteredRepos
        let running = items.filter(\.isRunning)
        let recent = items.filter { !$0.isRunning }

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    statsStrip
                    freshnessLine
                    filterBar

                    if items.isEmpty {
                        ContentUnavailableView {
                            Label("没有匹配的仓库", systemImage: "shippingbox")
                        } description: {
                            Text(searchText.isEmpty ? "下拉刷新试试" : "换个关键词")
                        }
                        .padding(.top, 48)
                    }

                    if !running.isEmpty {
                        SectionLabel("正在构建")
                        ForEach(running) { repo in
                            row(repo)
                        }
                    }

                    if !recent.isEmpty {
                        SectionLabel(running.isEmpty ? "全部仓库" : "最近完成")
                        ForEach(recent) { repo in
                            row(repo)
                        }
                    }
                }
                .padding(.bottom, Metrics.tabBarClearance)
            }
            .scrollIndicators(.hidden)
            .background(PaperBackground())
            .navigationTitle("构建")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索仓库")
            .refreshable { await environment.monitor.refreshNow() }
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
                        if isSyncing {
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

    private func row(_ repo: RepoRecord) -> some View {
        NavigationLink(value: repo.fullName) {
            RepoRowView(repo: repo)
        }
        .buttonStyle(.plain)
    }

    /// 顶部三个数字。没有胶囊、没有图标、没有底色——
    /// 数字本身就是信息，装饰只会稀释它。
    private var statsStrip: some View {
        HStack(spacing: 0) {
            MetricCell(value: "\(activeCount)", label: "在跑", tint: activeCount > 0 ? StatusTone.running : nil)
            VerticalRule()
            MetricCell(value: "\(failingCount)", label: "失败", tint: failingCount > 0 ? StatusTone.failed : nil)
            VerticalRule()
            MetricCell(value: "\(visibleRepos.count)", label: "仓库")
        }
        .padding(.horizontal, DS.pad)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    /// 让人知道数据是活的。没有这行，一个不动的数字很容易被当成卡死。
    private var freshnessLine: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            Text(freshness(context.date))
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
                .padding(.horizontal, DS.pad)
                .padding(.bottom, 10)
        }
    }

    private func freshness(_ now: Date) -> String {
        guard let last = environment.monitor.lastRefreshAt else { return "尚未刷新" }
        let seconds = Int(now.timeIntervalSince(last))
        if seconds < 5 { return "刚刚更新" }
        if seconds < 60 { return "\(seconds) 秒前更新" }
        if seconds < 3600 { return "\(seconds / 60) 分钟前更新" }
        return "\(seconds / 3600) 小时前更新"
    }

    private var filterBar: some View {
        Picker("筛选", selection: $filter) {
            ForEach(RepoFilter.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DS.pad)
        .padding(.bottom, 14)
    }

    private var activeCount: Int {
        visibleRepos.reduce(0) { $0 + $1.activeRunCount }
    }

    private var failingCount: Int {
        visibleRepos.filter(\.latestFailed).count
    }

    private var visibleRepos: [RepoRecord] {
        repos.filter { !$0.isHidden }
    }

    private var filteredRepos: [RepoRecord] {
        var items = visibleRepos

        switch filter {
        case .all:
            break
        case .running:
            items = items.filter(\.isRunning)
        case .failing:
            items = items.filter(\.latestFailed)
        }

        if !searchText.isEmpty {
            items = items.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
        }

        // 在跑的顶到最前，其余按最近一次构建排序
        return items.sorted { lhs, rhs in
            if lhs.isRunning != rhs.isRunning { return lhs.isRunning }
            return (lhs.latestRunAt ?? .distantPast) > (rhs.latestRunAt ?? .distantPast)
        }
    }

    private func sync() async {
        isSyncing = true
        defer { isSyncing = false }
        try? await environment.repos.syncAll()
        await environment.monitor.refreshNow()
    }
}
