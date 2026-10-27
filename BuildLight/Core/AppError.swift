import Foundation

/// 面向用户的错误分类。不同类别在界面上有不同处理方式，
/// 不要把它们压成一行字符串——那会丢信息和断掉恢复路径。
enum AppError: LocalizedError, Equatable, Sendable {
    /// Token 失效或权限不足：引导重新登录。
    case unauthorized
    /// 仓库不存在或看不到：提示检查名字/权限。
    case notFound
    /// 触发限流：显示恢复时间，倒计时期间降低频率。
    case rateLimited(resetAt: Date?)
    /// 网络不可达：可重试，保留上次数据。
    case offline
    /// 服务端 5xx：可重试。
    case server(status: Int)
    /// 数据格式不符合预期：属于 App 的问题，需要上报。
    case decoding(String)
    /// 产物已过期或不存在。
    case artifactUnavailable
    /// 解压后没有找到 .ipa。
    case packageMissing
    /// 压缩包损坏。
    case archiveInvalid(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "登录已失效，请重新填写 Token"
        case .notFound: return "仓库不存在，或这个 Token 没有访问权限"
        case .rateLimited(let reset):
            guard let reset else { return "GitHub 接口调用超限" }
            return "接口调用超限，\(Self.clock.string(from: reset)) 后恢复"
        case .offline: return "网络不可用，显示的是上次数据"
        case .server(let status): return "GitHub 返回 \(status)，稍后重试"
        case .decoding(let detail): return "数据解析失败：\(detail)"
        case .artifactUnavailable: return "构建产物已过期"
        case .packageMissing: return "压缩包里没有找到 ipa"
        case .archiveInvalid(let detail): return "压缩包无法读取：\(detail)"
        }
    }

    /// 是否值得自动重试。
    var isRetryable: Bool {
        switch self {
        case .offline, .server: return true
        case .rateLimited: return false
        case .unauthorized, .notFound, .decoding: return false
        case .artifactUnavailable, .packageMissing, .archiveInvalid: return false
        }
    }

    static func map(_ error: Error) -> AppError {
        if let app = error as? AppError { return app }
        if let gh = error as? GitHubError {
            switch gh {
            case .unauthorized: return .unauthorized
            case .notFound: return .notFound
            case .rateLimited(let reset): return .rateLimited(resetAt: reset)
            case .decoding(let detail): return .decoding(detail)
            case .transport: return .offline
            case .http(let status, _):
                return status >= 500 ? .server(status: status) : .decoding("HTTP \(status)")
            }
        }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost:
                return .offline
            default: return .offline
            }
        }
        return .decoding(error.localizedDescription)
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
