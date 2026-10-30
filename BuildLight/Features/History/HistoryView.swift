import SwiftUI
import SwiftData

/// 历史页：按仓库分组，每组可折叠。
///
/// 用 `ScrollView` 而不是 `List`：
/// 折叠展开需要自绘的分组头（带状态点、记录数、旋转箭头），
/// `List` 的 Section header 在视觉上限制太多，
/// 而且这里不需要 swipeActions，List 的好处用不上。
struct HistoryView: View {
    @Query(sort: \RunRecord.createdAt, order: .reverse) private var runs: [RunRecord]

    @State private var expandedRepoIDs: Set<String> = []
    @State private var hasInitialized = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(groups) { group in
                        HistoryRepoSection(group: group, expandedRepoIDs: $expandedRepoIDs)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .padding(.bottom, Metrics.tabBarClearance)
            }
            .scrollIndicators(.hidden)
            .background(PaperBackground())
            .navigationTitle("历史")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: RunRoute.self) { route in
                if let run = runs.first(where: { $0.id == route.runID }) {
                    RunDetailView(run: run)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !groups.isEmpty {
                        Button(allExpanded ? "收起" : "展开", systemImage: allExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical") {
                            withAnimation(Motion.settle) {
                                if allExpanded {
                                    expandedRepoIDs.removeAll()
                                } else {
                                    expandedRepoIDs = Set(groups.map(\.id))
                                }
                            }
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel(allExpanded ? "收起全部" : "展开全部")
                    }
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
            .task {
                // 首次进入默认展开最近活跃的那个，或全部（仓库少时）
                guard !hasInitialized, !groups.isEmpty else { return }
                hasInitialized = true
                if groups.count <= 3 {
                    expandedRepoIDs = Set(groups.map(\.id))
                } else if let first = groups.first {
                    expandedRepoIDs = [first.id]
                }
            }
        }
    }

    private var allExpanded: Bool {
        !groups.isEmpty && expandedRepoIDs.count == groups.count
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
