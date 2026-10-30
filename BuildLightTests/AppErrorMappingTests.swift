import Testing
import Foundation
@testable import BuildLight

/// 错误分类。
///
/// 映射错一次的后果很具体：切个后台再回来，
/// 顶部就挂一条「网络不可用」，而其实所有请求都正常。
struct AppErrorMappingTests {
    @Test("任务取消不是网络错误")
    func cancellationError() {
        #expect(AppError.map(CancellationError()) == .cancelled)
    }

    @Test("URLError.cancelled 同样处理")
    func urlCancelled() {
        #expect(AppError.map(URLError(.cancelled)) == .cancelled)
    }

    @Test("真正断网才映射为 offline")
    func offline() {
        #expect(AppError.map(URLError(.notConnectedToInternet)) == .offline)
        #expect(AppError.map(URLError(.timedOut)) == .offline)
    }

    @Test("GitHub 5xx 映射为 server")
    func serverError() {
        #expect(AppError.map(GitHubError.http(status: 502, message: nil)) == .server(status: 502))
    }

    @Test("401 映射为未授权")
    func unauthorized() {
        #expect(AppError.map(GitHubError.unauthorized) == .unauthorized)
    }

    @Test("已经是 AppError 时原样返回")
    func passthrough() {
        #expect(AppError.map(AppError.artifactUnavailable) == .artifactUnavailable)
    }

    @Test("取消不显示给用户")
    func cancelledIsRetryableButQuiet() {
        #expect(AppError.cancelled.isRetryable)
        #expect(!AppError.map(CancellationError()).shouldSurface)
    }
}

extension AppError {
    /// 是否值得占用顶部提示条。
    var shouldSurface: Bool { self != .cancelled }
}
