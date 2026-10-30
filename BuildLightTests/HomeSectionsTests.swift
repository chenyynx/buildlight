import Testing
import Foundation
@testable import BuildLight

/// 首页分组规则。
///
/// 这决定「可安装」区里出现哪些仓库——是用户打开 App 第一眼看到的东西。
struct HomeSectionsTests {
    struct Item: HomeSectionItem {
        let fullName: String
        var isRunning: Bool = false
        var hasPackage: Bool = false
    }

    private func make(
        _ items: [Item],
        ready: Set<String> = []
    ) -> HomeSections<Item> {
        HomeSections.make(from: items) { ready.contains($0.fullName) }
    }

    @Test("已下载的进 ready，未下载的进 available")
    func splitsPackages() {
        let items = [
            Item(fullName: "a/one", hasPackage: true),
            Item(fullName: "a/two", hasPackage: true)
        ]
        let sections = make(items, ready: ["a/one"])

        #expect(sections.ready.map(\.id) == ["a/one"])
        #expect(sections.available.map(\.id) == ["a/two"])
    }

    @Test("正在跑的优先归到 running，即使有包")
    func runningWins() {
        let items = [Item(fullName: "a/one", isRunning: true, hasPackage: true)]
        let sections = make(items, ready: ["a/one"])

        #expect(sections.running.map(\.id) == ["a/one"])
        #expect(sections.ready.isEmpty)
        #expect(sections.available.isEmpty)
    }

    @Test("没有包也不在跑 → idle")
    func idleFallback() {
        let sections = make([Item(fullName: "a/one")])
        #expect(sections.idle.map(\.id) == ["a/one"])
    }

    @Test("actionable = ready + available")
    func actionable() {
        let items = [
            Item(fullName: "a/one", hasPackage: true),
            Item(fullName: "a/two", hasPackage: true),
            Item(fullName: "a/three")
        ]
        let sections = make(items, ready: ["a/one"])
        #expect(sections.actionable.count == 2)
        #expect(!sections.isEmpty)
    }

    @Test("空输入")
    func empty() {
        let sections = make([])
        #expect(sections.isEmpty)
        #expect(sections.actionable.isEmpty)
    }

    @Test("顺序保持输入顺序")
    func preservesOrder() {
        let items = [
            Item(fullName: "z", hasPackage: true),
            Item(fullName: "a", hasPackage: true),
            Item(fullName: "m", hasPackage: true)
        ]
        let sections = make(items, ready: ["z", "a", "m"])
        #expect(sections.ready.map(\.id) == ["z", "a", "m"])
    }

    @Test("每个条目恰好落在一个分组")
    func exactlyOnce() {
        let items = [
            Item(fullName: "a", isRunning: true),
            Item(fullName: "b", hasPackage: true),
            Item(fullName: "c"),
            Item(fullName: "d", hasPackage: true)
        ]
        let sections = make(items, ready: ["b"])
        let all = (sections.ready + sections.available + sections.running + sections.idle).map(\.id)
        #expect(Set(all) == Set(["a", "b", "c", "d"]))
        #expect(all.count == 4)
    }
}
