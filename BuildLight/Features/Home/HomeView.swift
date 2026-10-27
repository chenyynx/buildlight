import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    @State private var showingPicker = false

    private var palette: Palette { .resolve(colorScheme) }

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
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingPicker = true
                } label: {
                    Label("添加仓库", systemImage: "plus")
                }
            }
        }
        .refreshable { await environment.monitor.refreshNow() }
        .sheet(isPresented: $showingPicker) {
            RepoPickerView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            MicroLabel(text: "Build light", color: palette.textTertiary)
                .padding(.top, 10)
            Text("构建")
                .font(.display(34))
                .foregroundStyle(palette.textPrimary)
                .padding(.top, 6)
            Text(summaryText)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.textSecondary)
                .padding(.top, 6)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryText: String {
        guard !repos.isEmpty else { return "还没有仓库" }

        let activeTotal = repos.reduce(0) { $0 + $1.runs.filter(\.isActive).count }
        // 只看每个仓库最近一条，避免历史里有过失败就一直计数
        let failing = repos.filter { repo in
            guard let latest = repo.runs.max(by: { $0.createdAt < $1.createdAt }) else { return false }
            return latest.conclusion == .failure
        }.count

        var parts: [String] = []
        parts.append(activeTotal > 0 ? "\(activeTotal) 个在跑" : "全部空闲")
        if failing > 0 { parts.append("\(failing) 个失败") }
        parts.append("\(repos.count) 个仓库")
        return parts.joined(separator: " · ")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有仓库", systemImage: "shippingbox")
        } description: {
            Text("点右上角 + 从你有权限的仓库里选")
        }
        .padding(.top, 60)
    }
}
