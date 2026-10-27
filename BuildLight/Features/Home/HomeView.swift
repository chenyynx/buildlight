import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]
    @State private var isAdding = false

    private var palette: DesignPalette { .resolve(colorScheme) }
    private var activeCount: Int { repos.reduce(0) { $0 + $1.runs.filter(\.isActive).count } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                header
                ForEach(repos) { repo in
                    NavigationLink {
                        RepoDetailView(repo: repo)
                    } label: {
                        RepoCard(repo: repo, palette: palette)
                    }
                    .buttonStyle(.plain)
                }
                if repos.isEmpty && !environment.monitor.isRefreshing {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .background(palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAdding = true
                } label: {
                    Label("添加仓库", systemImage: "plus")
                }
            }
        }
        .refreshable { await environment.monitor.refreshNow() }
        .sheet(isPresented: $isAdding) {
            AddRepoSheet()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            MicroLabel(text: "Build light", color: palette.textTertiary)
                .padding(.top, 8)
            Text("构建")
                .font(.display(34))
                .foregroundStyle(palette.textPrimary)
                .padding(.top, 6)
            Text(summaryText)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.textSecondary)
                .padding(.top, 6)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryText: String {
        let failed = repos.reduce(0) { partial, repo in
            partial + (repo.runs.first(where: { $0.conclusion == .failure }) == nil ? 0 : 1)
        }
        var parts: [String] = []
        parts.append(activeCount > 0 ? "\(activeCount) 个在跑" : "全部空闲")
        if failed > 0 { parts.append("\(failed) 个失败") }
        parts.append("\(repos.count) 个仓库")
        return parts.joined(separator: " · ")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有仓库", systemImage: "shippingbox")
        } description: {
            Text("点右上角 + 添加一个 owner/repo")
        }
        .padding(.top, 60)
    }
}
