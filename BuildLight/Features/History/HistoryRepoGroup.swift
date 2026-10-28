import Foundation

/// 历史按项目分组，避免不同仓库的运行混在一起。
struct HistoryRepoGroup: Identifiable {
    let repoFullName: String
    let runs: [RunRecord]

    var id: String { repoFullName }

    var displayName: String {
        repoFullName.split(separator: "/").last.map(String.init) ?? repoFullName
    }
}
