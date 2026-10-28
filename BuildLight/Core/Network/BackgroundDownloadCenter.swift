import Foundation
import UIKit

/// 后台下载中心。
///
/// 默认的 `URLSession` 在 App 挂起后就停了。换成 background configuration 之后：
/// - App 退到后台，下载继续跑；
/// - 下载完成时 App 不在前台，系统会把 App 拉起来收文件；
/// - 收到文件先落在临时目录并把「待完成」记录写进 UserDefaults，
///   等用户回到 App 再解压入库（解压必须在前台做，ZIPFoundation 不适合在后台跑）。
final class BackgroundDownloadCenter: NSObject, @unchecked Sendable {
    static let shared = BackgroundDownloadCenter()
    static let identifier = "org.example.buildlight.downloads"
    private static let pendingKey = "bg.pending.downloads"
    private static let availableKey = "bg.download.available"
    /// 12 秒没有任何字节进来就判定这条通道不可用，之后一律走普通会话。
    private static let stallSeconds: UInt64 = 12
    /// 传输中途 30 秒没有字节 = 连接死了。S3 的长连接偶尔会静默断掉，
    /// 不掐的话进度就永远停在中途（用户截图里的 44%）。
    private static let midStallSeconds: UInt64 = 30

    /// 某些签名方式下后台会话根本收不到回调（表现为进度恒为 0）。
    /// 探测到一次无响应就永久降级，避免每次下载都白等 12 秒。
    static var isAvailable: Bool {
        get { UserDefaults.standard.object(forKey: availableKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: availableKey) }
    }

    struct Pending: Codable {
        let artifactID: Int
        let name: String
        let path: String
    }

    private var session: URLSession!
    private let lock = NSLock()
    private var continuations: [Int: CheckedContinuation<URL, Error>] = [:]
    private var progressHandlers: [Int: @Sendable (Double) -> Void] = [:]
    private var movedURLs: [Int: URL] = [:]
    private var liveTasks: [Int: URLSessionDownloadTask] = [:]
    private var watchdogs: [Int: Task<Void, Never>] = [:]
    private var progressed: [Int: Bool] = [:]
    private var lastByteAt: [Int: ContinuousClock.Instant] = [:]

    var backgroundCompletionHandler: (() -> Void)?

    private override init() {
        let config = URLSessionConfiguration.background(withIdentifier: Self.identifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.timeoutIntervalForResource = 3600
        config.httpMaximumConnectionsPerHost = 2
        super.init()
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: 对外

    func download(
        _ request: URLRequest,
        artifactID: Int,
        name: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // 之前被杀掉的进程可能已经下完了，直接交付，不重复下载
        if let finished = Self.takePending(artifactID: artifactID) {
            return URL(fileURLWithPath: finished.path)
        }

        guard Self.isAvailable else {
            throw GitHubError.transport("后台下载不可用")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: request)
            task.taskDescription = "\(artifactID)|\(name)"
            let taskID = task.taskIdentifier

            lock.lock()
            continuations[taskID] = continuation
            progressHandlers[taskID] = onProgress
            liveTasks[taskID] = task
            progressed[taskID] = false
            lock.unlock()

            watchdogs[taskID] = Task { [weak self] in
                // 阶段一：开头 12 秒没响应 → 通道坏了，永久降级
                try? await Task.sleep(for: .seconds(Self.stallSeconds))
                guard let self, !Task.isCancelled else { return }
                let snapshot = self.stallSnapshot(taskID: taskID)
                guard snapshot.pending else { return }
                if !snapshot.advanced {
                    Self.isAvailable = false
                    snapshot.task?.cancel()
                    self.finish(taskID: taskID, result: .failure(GitHubError.transport("后台下载通道无响应")))
                    return
                }
                // 阶段二：有进度了，改盯中途停顿
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Self.midStallSeconds))
                    guard !Task.isCancelled else { return }
                    let now = self.stallSnapshot(taskID: taskID)
                    guard now.pending else { return }
                    if now.advanced { continue }
                    now.task?.cancel()
                    self.finish(taskID: taskID, result: .failure(GitHubError.transport("下载连接中断")))
                    return
                }
            }

            task.resume()
        }
    }

    /// 已经被系统在后台下完、但还没入库的条目。
    static func pendingDownloads() -> [Pending] {
        guard let data = UserDefaults.standard.data(forKey: pendingKey),
              let items = try? JSONDecoder().decode([Pending].self, from: data)
        else { return [] }
        return items
    }

    static func takePending(artifactID: Int) -> Pending? {
        var items = pendingDownloads()
        guard let index = items.firstIndex(where: { $0.artifactID == artifactID }) else { return nil }
        let item = items.remove(at: index)
        save(items)
        return item
    }

    private static func appendPending(_ item: Pending) {
        var items = pendingDownloads().filter { $0.artifactID != item.artifactID }
        items.append(item)
        save(items)
    }

    private static func save(_ items: [Pending]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: pendingKey)
    }

    /// 同步方法里加锁：Swift 6 不允许在 async 上下文直接 lock/unlock。
    private func stallSnapshot(taskID: Int) -> (pending: Bool, advanced: Bool, task: URLSessionDownloadTask?) {
        lock.lock()
        defer { lock.unlock() }
        let advanced: Bool
        if let at = lastByteAt[taskID] {
            advanced = at.duration(to: .now) < .seconds(Self.midStallSeconds)
        } else {
            advanced = progressed[taskID] ?? false
        }
        return (continuations[taskID] != nil, advanced, liveTasks[taskID])
    }

    private func finish(taskID: Int, result: Result<URL, Error>) {
        lock.lock()
        let continuation = continuations.removeValue(forKey: taskID)
        progressHandlers.removeValue(forKey: taskID)
        liveTasks.removeValue(forKey: taskID)
        progressed.removeValue(forKey: taskID)
        lastByteAt.removeValue(forKey: taskID)
        let watchdog = watchdogs.removeValue(forKey: taskID)
        lock.unlock()
        watchdog?.cancel()
        continuation?.resume(with: result)
    }
}

extension BackgroundDownloadCenter: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let artifactID = Int(downloadTask.taskDescription?.split(separator: "|").first ?? "") ?? 0
        let name = downloadTask.taskDescription?.split(separator: "|").last.map(String.init) ?? "package"

        do {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("bl-bg", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent("\(artifactID)-\(UUID().uuidString).zip")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)

            if artifactID > 0 {
                Self.appendPending(Pending(artifactID: artifactID, name: name, path: destination.path))
            }
            lock.lock()
            movedURLs[downloadTask.taskIdentifier] = destination
            lock.unlock()

            // 文件已经落盘就算成功，不等 didCompleteWithError。
            // 后台会话在部分签名环境下不会回调完成事件，等它就会永远卡在 100%。
            finish(taskID: downloadTask.taskIdentifier, result: .success(destination))
        } catch {
            finish(taskID: downloadTask.taskIdentifier, result: .failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let value = min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0), 1)
        lock.lock()
        progressed[downloadTask.taskIdentifier] = true
        lastByteAt[downloadTask.taskIdentifier] = .now
        let handler = progressHandlers[downloadTask.taskIdentifier]
        lock.unlock()
        handler?(value)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            finish(taskID: task.taskIdentifier, result: .failure(error))
            return
        }
        if let status = (task.response as? HTTPURLResponse)?.statusCode, !(200...299).contains(status) {
            finish(taskID: task.taskIdentifier, result: .failure(GitHubError.http(status: status, message: "artifact 下载失败")))
            return
        }
        lock.lock()
        let moved = movedURLs.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        guard let moved else {
            finish(taskID: task.taskIdentifier, result: .failure(GitHubError.transport("下载完成后找不到文件")))
            return
        }
        finish(taskID: task.taskIdentifier, result: .success(moved))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var request = request
        // GitHub 会 302 到 S3 预签名地址，跨域必须摘掉 Token，否则 S3 拒绝
        if request.url?.host != "api.github.com" {
            request.setValue(nil, forHTTPHeaderField: "Authorization")
            request.setValue(nil, forHTTPHeaderField: "Accept")
        }
        completionHandler(request)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
