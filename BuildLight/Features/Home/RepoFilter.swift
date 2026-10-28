import Foundation

enum RepoFilter: String, CaseIterable, Identifiable {
    case all
    case running
    case failing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .running: return "在跑"
        case .failing: return "失败"
        }
    }
}
