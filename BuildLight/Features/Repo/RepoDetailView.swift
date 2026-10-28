import SwiftUI
import SwiftData

struct RepoDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query private var runs: [RunRecord]

    private let repo: RepoRecord

    init(repo: RepoRecord) {
        self.repo = repo
        let fullName = repo.fullName
        _runs = Query(
            filter: #Predicate<RunRecord> { $0.repoFullName == fullName },
            sort: [SortDescriptor(\RunRecord.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        List {
            ForEach(filteredRuns) { run in
                NavigationLink(value: RunRoute(runID: run.id)) {
                    RunRow(run: run)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if run.isActive {
                        Button("取消", systemImage: "xmark", role: .destructive) {
                            cancel(run)
                        }
                    } else {
                        Button("重跑", systemImage: "arrow.clockwise") {
                            rerun(run)
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(repo.displayName)
        .navigationDestination(for: RunRoute.self) { route in
            if let run = filteredRuns.first(where: { $0.id == route.runID }) {
                RunDetailView(run: run)
            }
        }
        .refreshable {
            await environment.monitor.refreshNow()
        }
        .overlay {
            if filteredRuns.isEmpty {
                ContentUnavailableView(
                    "还没有运行记录",
                    systemImage: "hammer",
                    description: Text("下拉可以刷新")
                )
            }
        }
    }

    private var filteredRuns: [RunRecord] {
        guard let filter = repo.workflowFilter, !filter.isEmpty else { return runs }
        return runs.filter { $0.workflowName == filter }
    }

    private func rerun(_ run: RunRecord) {
        guard let client = environment.session.client else { return }
        Task { try? await client.rerun(owner: repo.owner, repo: repo.name, runID: run.id) }
    }

    private func cancel(_ run: RunRecord) {
        guard let client = environment.session.client else { return }
        Task { try? await client.cancel(owner: repo.owner, repo: repo.name, runID: run.id) }
    }
}
