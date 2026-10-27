import Foundation

// MARK: - 错误

enum GitHubError: LocalizedError {
    case unauthorized
    case notFound
    case rateLimited(reset: Date?)
    case http(status: Int, message: String?)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Token 无效或已过期"
        case .notFound: return "仓库不存在或无权限"
        case .rateLimited(let reset):
            if let reset {
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                return "触发限流，\(f.string(from: reset)) 后恢复"
            }
            return "触发 GitHub 限流"
        case .http(let status, let message):
            return "HTTP \(status)" + (message.map { " · \($0)" } ?? "")
        case .decoding(let detail): return "数据解析失败：\(detail)"
        case .transport(let detail): return "网络错误：\(detail)"
        }
    }
}

// MARK: - 重定向去鉴权

/// GitHub 的 artifact 下载接口返回 302 到 S3 预签名地址。
/// 预签名 URL 不接受额外的 Authorization 头，跨域时必须剥掉。
private final class ArtifactRedirector: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        var request = request
        if request.url?.host != "api.github.com" {
            request.setValue(nil, forHTTPHeaderField: "Authorization")
            request.setValue(nil, forHTTPHeaderField: "Accept")
        }
        return request
    }
}

// MARK: - 客户端

actor GitHubClient {
    private let token: String
    private let baseURL = URL(string: "https://api.github.com")!
    private let plain: URLSession
    private let redirecting: URLSession
    private let decoder: JSONDecoder
    private var etagCache: [String: (etag: String, body: Data)] = [:]
    private(set) var lastRateLimitRemaining: Int?
    private(set) var lastRateLimitReset: Date?

    init(token: String) {
        self.token = token
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 300
        config.httpAdditionalHeaders = ["User-Agent": "BuildLight/0.1"]
        self.plain = URLSession(configuration: config)
        self.redirecting = URLSession(configuration: config, delegate: ArtifactRedirector(), delegateQueue: nil)

        self.decoder = GitHubJSON.makeDecoder()
    }

    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let iso8601WithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: 请求

    private func get(_ path: String, query: [URLQueryItem] = [], allowCache: Bool = true) async throws -> Data {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let key = components.url!.absoluteString
        if allowCache, let cached = etagCache[key] {
            request.setValue(cached.etag, forHTTPHeaderField: "If-None-Match")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await plain.data(for: request)
        } catch {
            throw GitHubError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.transport("响应无效")
        }

        updateRateLimit(from: http)

        switch http.statusCode {
        case 200...299:
            if let etag = http.value(forHTTPHeaderField: "ETag"), allowCache {
                etagCache[key] = (etag, data)
            }
            return data
        case 304:
            guard let cached = etagCache[key] else { throw GitHubError.http(status: 304, message: "缓存缺失") }
            return cached.body
        case 401:
            throw GitHubError.unauthorized
        case 403, 429:
            if http.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
                throw GitHubError.rateLimited(reset: lastRateLimitReset)
            }
            throw GitHubError.http(status: http.statusCode, message: nil)
        case 404:
            throw GitHubError.notFound
        default:
            let message = String(data: data, encoding: .utf8)
            throw GitHubError.http(status: http.statusCode, message: message?.prefix(200).description)
        }
    }

    private func updateRateLimit(from http: HTTPURLResponse) {
        if let remaining = http.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap(Int.init) {
            lastRateLimitRemaining = remaining
        }
        if let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(TimeInterval.init) {
            lastRateLimitReset = Date(timeIntervalSince1970: reset)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw GitHubError.decoding(String(describing: error).prefix(300).description)
        }
    }

    // MARK: 接口

    /// 校验 token 并返回当前账号。
    func currentUser() async throws -> Actor {
        try await decode(Actor.self, from: get("/user"))
    }

    func repository(owner: String, name: String) async throws -> RepositorySummary {
        try await decode(RepositorySummary.self, from: get("/repos/\(owner)/\(name)"))
    }

    /// 最近一次运行，可按工作流名过滤。
    func latestRun(owner: String, repo: String, workflow: String? = nil) async throws -> WorkflowRun? {
        let page: RunsPage = try await decode(
            RunsPage.self,
            from: try await get("/repos/\(owner)/\(repo)/actions/runs", query: [URLQueryItem(name: "per_page", value: "1")])
        )
        _ = workflow
        return page.workflowRuns.first
    }

    func runs(owner: String, repo: String, perPage: Int = 20, branch: String? = nil) async throws -> [WorkflowRun] {
        var query = [URLQueryItem(name: "per_page", value: String(perPage))]
        if let branch, !branch.isEmpty { query.append(URLQueryItem(name: "branch", value: branch)) }
        let page: RunsPage = try await decode(
            RunsPage.self,
            from: try await get("/repos/\(owner)/\(repo)/actions/runs", query: query)
        )
        return page.workflowRuns
    }

    func jobs(owner: String, repo: String, runID: Int) async throws -> [WorkflowJob] {
        let page: JobsPage = try await decode(
            JobsPage.self,
            from: try await get("/repos/\(owner)/\(repo)/actions/runs/\(runID)/jobs", query: [URLQueryItem(name: "per_page", value: "50")])
        )
        return page.jobs
    }

    func artifacts(owner: String, repo: String, runID: Int) async throws -> [Artifact] {
        let page: ArtifactsPage = try await decode(
            ArtifactsPage.self,
            from: try await get("/repos/\(owner)/\(repo)/actions/runs/\(runID)/artifacts", query: [URLQueryItem(name: "per_page", value: "30")])
        )
        return page.artifacts.filter { !$0.expired }
    }

    /// 下载 artifact 的 zip 到临时目录。
    func downloadArtifact(_ artifact: Artifact) async throws -> URL {
        var request = URLRequest(url: artifact.archiveDownloadUrl)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (url, response) = try await redirecting.download(for: request)
            guard let http = response as? HTTPURLResponse else { throw GitHubError.transport("响应无效") }
            guard (200...299).contains(http.statusCode) else {
                throw GitHubError.http(status: http.statusCode, message: "artifact 下载失败")
            }
            let target = FileManager.default.temporaryDirectory
                .appendingPathComponent("bl-\(artifact.id)-\(UUID().uuidString)")
                .appendingPathExtension("zip")
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: url, to: target)
            return target
        } catch let error as GitHubError {
            throw error
        } catch {
            throw GitHubError.transport(error.localizedDescription)
        }
    }
}
