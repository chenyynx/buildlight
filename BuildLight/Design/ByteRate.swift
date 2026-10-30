import Foundation

/// 把字节/秒格式化成「3.2 MB/s」。
enum ByteRate {
    static func text(_ bytesPerSecond: Double) -> String? {
        guard bytesPerSecond > 1024 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }
}
