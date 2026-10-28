import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \RunRecord.createdAt, order: .reverse) private var runs: [RunRecord]

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    HistoryRepoGroupView(group: group)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("历史")
            .navigationDestination(for: RunRoute.self) { route in
                if let run = runs.first(where: { $0.id == route.runID }) {
                    RunDetailView(run: run)
                }
            }
            .overlay {
                if runs.isEmpty {
                    ContentUnavailableView(
                        "还没有记录",
                        systemImage: "clock",
                        description: Text("添加仓库后这里会出现构建历史")
                    )
                }
            }
        }
    }

    private var groups: [HistoryRepoGroup] {
        Dictionary(grouping: runs, by: \.repoFullName)
            .map { HistoryRepoGroup(repoFullName: $0.key, runs: $0.value) }
            .sorted { lhs, rhs in
                let left = lhs.runs.first?.createdAt ?? .distantPast
                let right = rhs.runs.first?.createdAt ?? .distantPast
                return left > right
            }
    }
}
