import Foundation

/// 带进度的 artifact 下载。GitHub 会 302 到 S3 预签名地址，
/// 跨域时必须把 Authorization 头去掉，否则 S3 会拒绝。
final class ArtifactDownloader: NSObject, @unchecked Sendable {
    private var continuation: CheckedContinuation<URL, Error>?
    private var progressHandler: (@Sendable (Double) -> Void)?
    private var finished = false
    private var movedURL: URL?

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
            session.downloadTask(with: request).resume()
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard !finished else { return }
        finished = true
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
