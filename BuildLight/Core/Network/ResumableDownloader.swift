import Foundation

/// 可以暂停、可以续传、跨进程存活的文件下载器。
///
/// 为什么不用 `URLSessionDownloadTask`：
/// - 它的进度在内存里，App 一被杀就没了；
/// - 中断后只能靠系统保留的 resumeData，而且重启即失效；
/// - 它的「完成」要等系统回调，自签环境下这个回调不一定来——这正是卡在 100% 的原因。
///
/// 这里改成流式 data task：
/// - 边收边写进 `Application Support/Downloads/<id>.part`，字节落盘，进程死不了；
/// - 旁边的 `<id>.json` 记着总长度和源地址，下次启动就知道「已经下了多少」；
/// - 续传时发 `Range: bytes=N-`，S3 支持，返回 206 就接着写；
/// - 是否完成由我们自己比较文件大小和 Content-Length 决定，不求人。
final class ResumableDownloader: NSObject, @unchecked Sendable {
    static let shared = ResumableDownloader()

    private struct Meta: Codable {
        var sourceURL: String
        var expected: Int64
    }

    private struct TaskState {
        let artifactID: Int
        let sourceURL: String
        let partURL: URL
        var expected: Int64
        var received: Int64
        var handle: FileHandle?
        var lastSampleAt = Date()
        var lastSampleBytes: Int64 = 0
        var speed: Double = 0
        var onProgress: (@Sendable (Double, Double) -> Void)?
        var continuation: CheckedContinuation<URL, Error>?
    }

    private let lock = NSLock()
    private let directory: URL
    private var session: URLSession!
    private var states: [Int: TaskState] = [:]

    private override init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("Downloads", isDirectory: true)
        super.init()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: 对外

    /// 已下载到第几成（0…1）。没有半截文件就返回 nil。
    func progressOnDisk(for artifactID: Int) -> Double? {
        guard let meta = readMeta(artifactID), meta.expected > 0,
              let size = fileSize(partURL(artifactID)), size > 0, size < meta.expected
        else { return nil }
        return min(max(Double(size) / Double(meta.expected), 0), 1)
    }

    func discard(artifactID: Int) {
        try? FileManager.default.removeItem(at: partURL(artifactID))
        try? FileManager.default.removeItem(at: metaURL(artifactID))
    }

    func download(
        artifactID: Int,
        request: URLRequest,
        onProgress: @escaping @Sendable (Double, Double) -> Void
    ) async throws -> URL {
        let source = request.url?.absoluteString ?? ""
        let part = partURL(artifactID)

        var offset: Int64 = 0
        if let meta = readMeta(artifactID), meta.sourceURL == source, let size = fileSize(part), size > 0 {
            offset = size
        } else {
            try? FileManager.default.removeItem(at: part)
        }

        var request = request
        if offset > 0 {
            request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request)
            task.taskDescription = "\(artifactID)|\(source)"

            lock.lock()
            states[task.taskIdentifier] = TaskState(
                artifactID: artifactID,
                sourceURL: source,
                partURL: part,
                expected: 0,
                received: offset,
                handle: nil,
                onProgress: onProgress,
                continuation: continuation
            )
            lock.unlock()

            task.resume()
        }
    }

    // MARK: 磁盘

    private func partURL(_ id: Int) -> URL {
        directory.appendingPathComponent("\(id).part")
    }

    private func metaURL(_ id: Int) -> URL {
        directory.appendingPathComponent("\(id).json")
    }

    private func readMeta(_ id: Int) -> Meta? {
        guard let data = try? Data(contentsOf: metaURL(id)) else { return nil }
        return try? JSONDecoder().decode(Meta.self, from: data)
    }

    private func writeMeta(_ id: Int, source: String, expected: Int64) {
        let meta = Meta(sourceURL: source, expected: expected)
        guard let data = try? JSONEncoder().encode(meta) else { return }
        try? data.write(to: metaURL(id), options: .atomic)
    }

    private func fileSize(_ url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int64
    }
}

extension ResumableDownloader: URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        let key = dataTask.taskIdentifier
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let length = response.expectedContentLength

        lock.lock()
        guard var state = states[key] else {
            lock.unlock()
            completionHandler(.cancel)
            return
        }

        // 206 = 服务器接受了续传；200 = 只能从头来
        let start: Int64
        if status == 206 {
            start = state.received
        } else {
            start = 0
            state.received = 0
        }
        state.expected = length > 0 ? start + length : 0

        let fm = FileManager.default
        if !fm.fileExists(atPath: state.partURL.path) {
            fm.createFile(atPath: state.partURL.path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: state.partURL) {
            if start == 0 {
                try? handle.truncate(atOffset: 0)
            } else {
                try? handle.seekToEnd()
            }
            state.handle = handle
        }

        states[key] = state
        lock.unlock()

        if state.expected > 0 {
            writeMeta(state.artifactID, source: state.sourceURL, expected: state.expected)
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let key = dataTask.taskIdentifier
        lock.lock()
        guard var state = states[key] else {
            lock.unlock()
            return
        }
        state.received += Int64(data.count)
        state.handle?.write(data)

        // 每 0.4 秒采一次速度，再做指数平滑，避免数字乱跳
        let now = Date()
        let elapsed = now.timeIntervalSince(state.lastSampleAt)
        if elapsed >= 0.4 {
            let delta = Double(state.received - state.lastSampleBytes)
            let instant = delta / elapsed
            state.speed = state.speed == 0 ? instant : state.speed * 0.7 + instant * 0.3
            state.lastSampleAt = now
            state.lastSampleBytes = state.received
        }

        let total = state.expected
        let received = state.received
        let speed = state.speed
        let handler = state.onProgress
        states[key] = state
        lock.unlock()

        guard total > 0 else { return }
        handler?(min(max(Double(received) / Double(total), 0), 1), speed)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let key = task.taskIdentifier
        lock.lock()
        let state = states.removeValue(forKey: key)
        lock.unlock()
        guard let state else { return }

        try? state.handle?.close()

        if let error {
            // 取消 / 断网：文件留在原地，下次接着下
            state.continuation?.resume(throwing: error)
            return
        }

        let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            state.continuation?.resume(throwing: GitHubError.http(status: status, message: "artifact 下载失败"))
            return
        }

        let size = fileSize(state.partURL) ?? 0
        if state.expected > 0, size < state.expected {
            state.continuation?.resume(throwing: GitHubError.transport("下载不完整，进度已保留"))
            return
        }

        // 走到这里就是完整文件，不等任何系统回调
        state.continuation?.resume(returning: state.partURL)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var request = request
        // GitHub 会 302 到 S3 预签名地址，跨域必须摘掉 Token
        if request.url?.host != "api.github.com" {
            request.setValue(nil, forHTTPHeaderField: "Authorization")
            request.setValue(nil, forHTTPHeaderField: "Accept")
        }
        completionHandler(request)
    }
}
