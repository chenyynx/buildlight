import Foundation
import Observation

/// 已下载产物的落盘管理。文件放在 Application Support/Packages，
/// 索引单独存一份 JSON，随时能看到占了多少空间、什么时候下的。
@MainActor
@Observable
final class CacheStore {
    struct Entry: Identifiable, Codable, Hashable {
        let id: Int
        var name: String
        var fileName: String
        var size: Int64
        var savedAt: Date
    }

    private(set) var entries: [Entry] = []

    private let directory: URL
    private let indexURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("Packages", isDirectory: true)
        indexURL = directory.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    var totalSize: Int64 {
        entries.reduce(0) { $0 + $1.size }
    }

    var totalSizeText: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    func url(for id: Int) -> URL? {
        guard let entry = entries.first(where: { $0.id == id }) else { return nil }
        let url = directory.appendingPathComponent(entry.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 把解压出来的 ipa 收进缓存，返回最终路径。
    func save(fileURL: URL, id: Int, name: String) throws -> URL {
        let fileName = "\(id)-\(name)"
        let destination = directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: fileURL, to: destination)

        let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? 0
        entries.removeAll { $0.id == id }
        entries.insert(
            Entry(id: id, name: name, fileName: fileName, size: size, savedAt: .now),
            at: 0
        )
        persist()
        return destination
    }

    func remove(_ id: Int) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(entry.fileName))
        entries.removeAll { $0.id == id }
        persist()
    }

    /// 清空全部，返回释放的字节数。
    @discardableResult
    func clearAll() -> Int64 {
        let freed = totalSize
        for entry in entries {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(entry.fileName))
        }
        entries = []
        persist()
        return freed
    }

    // MARK: 持久化

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data)
        else { return }
        // 文件被系统清掉时同步剔除，避免显示幽灵条目
        entries = decoded.filter {
            FileManager.default.fileExists(atPath: directory.appendingPathComponent($0.fileName).path)
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(entries) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }
}
