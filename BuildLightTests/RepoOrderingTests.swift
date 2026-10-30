import Testing
import Foundation
@testable import BuildLight

/// 仓库排序编号。
struct RepoOrderingTests {
    @Test("可见仓库占前排，隐藏仓库追加在后")
    func visibleThenHidden() {
        let map = RepoOrdering.assign(visible: ["a", "b"], hidden: ["c", "d"])
        #expect(map["a"] == 0)
        #expect(map["b"] == 1)
        #expect(map["c"] == 2)
        #expect(map["d"] == 3)
    }

    @Test("没有任何隐藏仓库时编号连续")
    func noHidden() {
        let map = RepoOrdering.assign(visible: ["a", "b", "c"], hidden: [])
        #expect(map.values.sorted() == [0, 1, 2])
    }

    @Test("全隐藏时从 0 开始")
    func allHidden() {
        let map = RepoOrdering.assign(visible: [], hidden: ["x", "y"])
        #expect(map["x"] == 0)
        #expect(map["y"] == 1)
    }

    @Test("移动后编号不重复且保持完整")
    func noDuplicatesAfterMove() {
        let map = RepoOrdering.assign(visible: ["c", "a", "b"], hidden: ["z"])
        let values = map.values.sorted()
        #expect(values == Array(0...3))
        #expect(Set(values).count == values.count)
    }

    @Test("reordered 与 IndexSet 语义一致")
    func reorderedMatchesMove() {
        let items = ["a", "b", "c", "d"]
        let result = RepoOrdering.reordered(items, moving: IndexSet(integer: 0), to: 3)
        #expect(result == ["b", "c", "a", "d"])
    }

    @Test("隐藏仓库的相对顺序不被打乱")
    func hiddenRelativeOrderStable() {
        let map = RepoOrdering.assign(visible: ["a"], hidden: ["c", "d"])
        #expect(map["c"]! < map["d"]!)
    }
}
