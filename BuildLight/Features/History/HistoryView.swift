import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \RunRecord.createdAt, order: .reverse) private var runs: [RunRecord]

    var body: some View {
        List {
            ForEach(groupedByDay, id: \.day) { group in
                Section {
                    ForEach(group.runs) { run in
                        NavigationLink {
                            if let repo = run.repo {
                                RunDetailView(run: run)
                                    .navigationTitle(repo.displayName)
                            } else {
                                RunDetailView(run: run)
                            }
                        } label: {
                            RunRow(run: run)
                        }
                    }
                } header: {
                    Text(dayTitle(group.day))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("历史")
        .navigationBarTitleDisplayMode(.large)
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

    private struct DayGroup {
        let day: Date
        let runs: [RunRecord]
    }

    private var groupedByDay: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: runs) { calendar.startOfDay(for: $0.createdAt) }
        return grouped
            .map { DayGroup(day: $0.key, runs: $0.value) }
            .sorted { $0.day > $1.day }
    }

    private func dayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter.string(from: date)
    }
}
