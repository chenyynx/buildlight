import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \RunRecord.createdAt, order: .reverse) private var runs: [RunRecord]

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.runs) { run in
                            NavigationLink(value: RunRoute(runID: run.id)) {
                                RunRow(run: run)
                            }
                        }
                    } header: {
                        Text(group.day, format: .dateTime.month(.wide).day())
                    }
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

    private var groups: [HistoryDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: runs) { calendar.startOfDay(for: $0.createdAt) }
        return grouped
            .map { HistoryDayGroup(day: $0.key, runs: $0.value) }
            .sorted { $0.day > $1.day }
    }
}
