import Foundation

/// 首页分组所依赖的最小信息集。
///
/// 不直接依赖 `RepoRecord`（SwiftData 的 @Model 需要容器才能安全构造），
/// 抽成协议后可以用纯值类型做单测。
protocol HomeSectionItem {
    var fullName: String { get }
    var isRunning: Bool { get }
    var hasPackage: Bool { get }
}

/// 首页的三段内容。
///
/// 为什么要分段而不是「一个列表排序」：用户打开 App 的第一个问题不是
/// 「有哪些仓库」，而是「现在有没有包可以装」。把可取包的仓库提到最上面，
/// 是在用信息架构代替用户去扫列表。
enum HomeSection<Item: HomeSectionItem>: Identifiable {
    /// 已经下好、可以直接导入的。
    case ready(Item)
    /// 有产物但还没下下来。
    case available(Item)
    /// 正在构建。
    case running(Item)
    /// 其余仓库。
    case idle(Item)

    var id: String { item.fullName }

    var item: Item {
        switch self {
        case .ready(let item), .available(let item), .running(let item), .idle(let item):
            item
        }
    }
}

/// 把仓库列表切成上面四段。
///
/// 优先级：可安装（已下载）> 有产物 > 在跑 > 其余。
/// 「在跑」排在「有产物」之后是有意的：用户来这个 App 主要是取包，
/// 正在跑意味着还得等，先让他把已经能装的装掉。
struct HomeSections<Item: HomeSectionItem> {
    let ready: [HomeSection<Item>]
    let available: [HomeSection<Item>]
    let running: [HomeSection<Item>]
    let idle: [HomeSection<Item>]

    /// 首页顶部的「现在能装什么」——只放真正能立刻动手的。
    var actionable: [HomeSection<Item>] { ready + available }

    var isEmpty: Bool {
        ready.isEmpty && available.isEmpty && running.isEmpty && idle.isEmpty
    }

    static func make(
        from items: [Item],
        isReady: (Item) -> Bool
    ) -> HomeSections {
        var ready: [HomeSection<Item>] = []
        var available: [HomeSection<Item>] = []
        var running: [HomeSection<Item>] = []
        var idle: [HomeSection<Item>] = []

        for item in items {
            if item.isRunning {
                running.append(.running(item))
            } else if item.hasPackage {
                if isReady(item) {
                    ready.append(.ready(item))
                } else {
                    available.append(.available(item))
                }
            } else {
                idle.append(.idle(item))
            }
        }

        return HomeSections(
            ready: ready,
            available: available,
            running: running,
            idle: idle
        )
    }
}

extension RepoRecord: HomeSectionItem {}
