import Foundation

/// 取包只需要这几个字段，不必把 SwiftData 的产物对象带进每一帧的视图计算。
struct PackageTarget: Hashable {
    let id: Int
    let name: String
    let archiveURL: URL

    init(id: Int, name: String, archiveURL: URL) {
        self.id = id
        self.name = name
        self.archiveURL = archiveURL
    }
}
