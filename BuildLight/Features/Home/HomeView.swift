import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    @State private var showingPicker = false
    @State private var pendingDeletion: RepoRecord?

    private var activeCount: Int {
        repos.reduce(0) { $0 + $1.runs.filter(\.isActive).count }
    }

    var body: some View {
        List {
            if !summaryText.isEmpty {
                Section {
                    Text(summaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(repos) { repo in
                    NavigationLink {
                        RepoDetailView(repo: repo)
                    } label: {
                        RepoRow(repo: repo)
                    }
                    .swipeActions {
                        Button("移除", role: .destructive) {
                            environment.repos.remove(repo)
                        }
                    }
                }
            }

            if repos.isEmpty {
                Section {
                    ContentUnavailableView(
                        "还没有仓库",
                        systemImage: "shippingbox",
                        description: Text("点右上角加号，从你有权限的仓库里选")
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("构建")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingPicker = true
                } label: {
                    Label("添加仓库", systemImage: "plus")
                }
            }
        }
        .refreshable {
            await environment.monitor.refreshNow()
        }
        .sheet(isPresented: $showingPicker) {
            RepoPickerView()
        }
    }

    private var summaryText: String {
        guard !repos.isEmpty else { return "" }
        let failed = repos.filter { repo in
            repo.runs.first(where: { $0.conclusion == .failure }) != nil
        }.count
        var parts: [String] = []
        parts.append(activeCount > 0 ? "\(activeCount) 个在跑" : "全部空闲")
        if failed > 0 { parts.append("\(failed) 个失败") }
        parts.append("\(repos.count) 个仓库")
        return parts.joined(separator: " · ")
    }
}
