import SwiftUI
import SwiftData

/// 历史页：按仓库分组的历史记录。
///
/// 保留 `List` 而不是卡片墙：历史页是低频查阅场景，
/// 信息密度比视觉冲击更重要。分组头用系统 Section header。
struct HistoryView: View {
    @Query(sort: \RunRecord.createdAt, order: .reverse) private var runs: [RunRecord]

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.runs) { run in
                            ZStack(alignment: .bottom) {
                                NavigationLink(value: RunRoute(runID: run.id)) {
                                    RunRowView(run: run)
                                }
                                .buttonStyle(PressableStyle())
                                Hairline(leading: DS.pad)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        HStack {
                            Text(group.repoFullName)
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.1)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text("\(group.runs.count)")
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.horizontal, DS.pad)
                        .padding(.top, 18)
                        .padding(.bottom, 4)
                        .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .background(PaperBackground())
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
