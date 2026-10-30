import Foundation

/// 仓库排序的纯计算（不碰 SwiftData，方便单测）。
///
/// 规则：可见仓库按新顺序占 0..n，隐藏仓库追加在后并保持相对顺序。
/// 之前只给可见仓库写序号，隐藏仓库保留旧值，
/// 恢复显示后会撞号、顺序错乱。
enum RepoOrdering {
    static func assign(
        visible: [String],
        hidden: [String]
    ) -> [String: Int] {
        var result: [String: Int] = [:]
        for (index, name) in visible.enumerated() {
            result[name] = index
        }
        for (offset, name) in hidden.enumerated() {
            result[name] = visible.count + offset
        }
        return result
    }

    /// 把 offsets 应用到一个标识符数组上，返回新顺序。
    static func reordered<T>(_ items: [T], moving offsets: IndexSet, to destination: Int) -> [T] {
        var copy = items
        copy.move(fromOffsets: offsets, toOffset: destination)
        return copy
    }
}
