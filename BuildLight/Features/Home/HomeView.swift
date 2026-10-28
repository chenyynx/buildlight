import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    @State private var filter: RepoFilter = .all
    @State private var searchText = ""
    @State private var syncError: AppError?
    @State private var didSync = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HomeHeader(repos: visibleRepos)

                    Picker("筛选", selection: $filter) {
                        ForEach(RepoFilter.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filteredRepos.isEmpty {
                        ContentUnavailableView {
                            Label("没有匹配的仓库", systemImage: "shippingbox")
                        } description: {
                            Text(searchText.isEmpty ? "下拉刷新试试" : "换个关键词")
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredRepos) { repo in
                                NavigationLink(value: repo.fullName) {
                                    RepoCardView(repo: repo)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(repo.isHidden ? "取消隐藏" : "隐藏", systemImage: repo.isHidden ? "eye" : "eye.slash") {
                                        environment.repos.setHidden(!repo.isHidden, for: repo)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Metrics.m)
                .padding(.bottom, Metrics.tabBarClearance)
            }
            .scrollIndicators(.hidden)
            .background { AnimatedBackdrop() }
            .navigationTitle("构建")
            .searchable(text: $searchText, prompt: "搜索仓库")
            .navigationDestination(for: String.self) { fullName in
                if let repo = repos.first(where: { $0.fullName == fullName }) {
                    RepoDetailView(repo: repo)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("同步仓库", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await sync() }
                    }
                }
            }
            .refreshable {
                await sync()
                await environment.monitor.refreshNow()
            }
            .task {
                guard !didSync else { return }
                didSync = true
                await sync()
                await environment.monitor.refreshNow()
            }
        }
    }

    private var visibleRepos: [RepoRecord] {
        repos.filter { !$0.isHidden }
    }

    private var filteredRepos: [RepoRecord] {
        var result = visibleRepos
        switch filter {
        case .all: break
        case .running: result = result.filter(\.isRunning)
        case .failing: result = result.filter { !$0.isRunning && $0.latestFailed }
        }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            result = result.filter { $0.fullName.localizedCaseInsensitiveContains(keyword) }
        }
        return result.sorted { lhs, rhs in
            if lhs.isRunning != rhs.isRunning { return lhs.isRunning }
            if lhs.latestFailed != rhs.latestFailed { return lhs.latestFailed }
            return lhs.sortIndex < rhs.sortIndex
        }
    }

    private func sync() async {
        do {
            try await environment.repos.syncAll()
            syncError = nil
        } catch {
            syncError = AppError.map(error)
        }
    }
}
