import SwiftUI

/// 历史里的一个项目分组：默认折叠，点开才展开这次的运行列表。
struct HistoryRepoGroupView: View {
    let group: HistoryRepoGroup

    @State private var isExpanded = false

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(group.runs) { run in
                    NavigationLink(value: RunRoute(runID: run.id)) {
                        HistoryRunRow(run: run)
                    }
                }
            } label: {
                HistoryGroupLabel(group: group)
            }
        }
    }
}
