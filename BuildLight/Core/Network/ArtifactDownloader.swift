import Foundation

/// 带进度的 artifact 下载。GitHub 会 302 到 S3 预签名地址，
/// 跨域时必须把 Authorization 头去掉，否则 S3 会拒绝。
final class ArtifactDownloader: NSObject, @unchecked Sendable {
    private var continuation: CheckedContinuation<URL, Error>?
    private var progressHandler: (@Sendable (Double) -> Void)?
    private var finished = false
    private var movedURL: URL?
    private var currentTask: URLSessionDownloadTask?
    /// 传输中途 30 秒没有字节 = 连接静默死亡，掐掉让用户重试。
    private var watchdog: Task<Void, Never>?
    private var lastByteAt: ContinuousClock.Instant?

    private static let midStallSeconds: UInt64 = 30

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 600
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    func download(
        _ request: URLRequest,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        progressHandler = onProgress
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let task = session.downloadTask(with: request)
            self.currentTask = task
            self.startWatchdog()
            task.resume()
        }
    }

    /// 循环检查：只要 30 秒内没有新字节就取消任务并报错。
    /// didWriteData 会重置时间戳，正常传输永远打不断。
    private func startWatchdog() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.midStallSeconds))
                guard !Task.isCancelled else { return }
                guard let task = self.currentTask, !self.finished else { return }
                let idle = self.lastByteAt.map { $0.duration(to: .now) >= .seconds(Self.midStallSeconds) } ?? true
                if idle {
                    task.cancel()
                    self.finish(.failure(GitHubError.transport("下载连接中断，请重试")))
                    return
                }
                self.lastByteAt = .now
            }
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard !finished else { return }
        finished = true
        currentTask = nil
        watchdog?.cancel()
        watchdog = nil
        continuation?.resume(with: result)
        continuation = nil
        progressHandler = nil
    }
}

extension ArtifactDownloader: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("bl-download-\(UUID().uuidString).zip")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            movedURL = destination
        } catch {
            finish(.failure(error))
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
        lastByteAt = .now
        let value = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler?(min(max(value, 0), 1))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            finish(.failure(error))
            return
        }
        if let status = (task.response as? HTTPURLResponse)?.statusCode, !(200...299).contains(status) {
            finish(.failure(GitHubError.http(status: status, message: "artifact 下载失败")))
            return
        }
        guard let movedURL else {
            finish(.failure(GitHubError.transport("下载完成后找不到文件")))
            return
        }
        finish(.success(movedURL))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var request = request
        if request.url?.host != "api.github.com" {
            request.setValue(nil, forHTTPHeaderField: "Authorization")
            request.setValue(nil, forHTTPHeaderField: "Accept")
        }
        completionHandler(request)
    }
}
