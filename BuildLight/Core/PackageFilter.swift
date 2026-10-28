import Foundation

/// GitHub 的 artifact 元数据里没有文件清单，只有名字和大小。
/// 所以这里宁可用名字做保守判断：只认像安装包的，日志、覆盖率、profile 一律不算。
/// 判错的代价是「少一个下载按钮」，而不是「下了 593KB 的 code-profile 发现没 ipa」。
enum PackageFilter {
    private static let markers = ["ipa", "unsigned", "payload", ".app", "installer"]

    static func looksLikeIPA(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return markers.contains { lowered.contains($0) }
    }
}
