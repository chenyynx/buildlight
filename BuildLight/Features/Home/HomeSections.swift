import Foundation

/// 首页的三段内容。
///
/// 为什么要分段而不是「一个列表排序」：用户打开 App 的第一个问题不是
/// 「有哪些仓库」，而是「现在有没有包可以装」。把可取包的仓库提到最上面，
/// 是在用信息架构代替用户去扫列表。
enum HomeSection: Identifiable, Hashable {
    /// 已经下好、可以直接导入的。
    case ready(RepoRecord)
    /// 有产物但还没下下来。
    case available(RepoRecord)
    /// 正在构建。
    case running(RepoRecord)
    /// 其余仓库。
    case idle(RepoRecord)

    var id: String { repo.fullName }

    var repo: RepoRecord {
        switch self {
        case .ready(let repo), .available(let repo), .running(let repo), .idle(let repo):
            repo
        }
    }

}

/// 把仓库列表切成上面四段。
///
/// 单独抽出来是为了让视图体保持干净，也方便单测。
struct HomeSections {
    let ready: [HomeSection]
    let available: [HomeSection]
    let running: [HomeSection]
    let idle: [HomeSection]

    /// 首页顶部的「现在能装什么」——只放真正能立刻动手的。
    var actionable: [HomeSection] { ready + available }

    var isEmpty: Bool {
        ready.isEmpty && available.isEmpty && running.isEmpty && idle.isEmpty
    }

    static func make(from repos: [RepoRecord], isReady: (RepoRecord) -> Bool) -> HomeSections {
        var ready: [HomeSection] = []
        var available: [HomeSection] = []
        var running: [HomeSection] = []
        var idle: [HomeSection] = []

        for repo in repos {
            if repo.isRunning {
                running.append(.running(repo))
            } else if repo.hasPackage {
                if isReady(repo) {
                    ready.append(.ready(repo))
                } else {
                    available.append(.available(repo))
                }
            } else {
                idle.append(.idle(repo))
            }
        }

        return HomeSections(ready: ready, available: available, running: running, idle: idle)
    }
}
