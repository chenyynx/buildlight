import Foundation

/// 导航用的一次运行标识。避免把 SwiftData 模型直接塞进导航值。
struct RunRoute: Hashable {
    let runID: Int
}
