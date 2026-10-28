import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    @State private var showingPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HomeHeader(repos: repos)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    ForEach(repos) { repo in
                        NavigationLink(value: repo.fullName) {
                            RepoRow(repo: repo)
                        }
                        .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                    }
                    .onDelete(perform: delete)
                }

                if repos.isEmpty && !environment.monitor.isRefreshing {
                    Section {
                        ContentUnavailableView {
                            Label("还没有仓库", systemImage: "shippingbox")
                        } description: {
                            Text("点右上角加号，从你有权限的仓库里选")
                        }
                        .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background { AnimatedBackdrop() }
            .navigationTitle("构建")
            .navigationDestination(for: String.self) { fullName in
                if let repo = repos.first(where: { $0.fullName == fullName }) {
                    RepoDetailView(repo: repo)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加仓库", systemImage: "plus") {
                        showingPicker = true
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
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            environment.repos.remove(repos[index])
        }
    }
}
