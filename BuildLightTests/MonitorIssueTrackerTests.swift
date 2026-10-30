import Testing
import Foundation
@testable import BuildLight

/// 错误生命周期。
///
/// 这组规则直接决定顶部那条「网络不可用」什么时候出现、什么时候消失，
/// 之前算错的代价是整块功能被用户当成「坏了」。
struct MonitorIssueTrackerTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test("失败后成功，错误消失")
    func clearsAfterSuccess() {
        var tracker = MonitorIssueTracker()
        tracker.recordFailure(repo: "a/b", error: .offline, at: t0)
        #expect(tracker.activeErrors["a/b"] == .offline)

        tracker.recordSuccess(repo: "a/b", at: t0.addingTimeInterval(10))
        #expect(tracker.activeErrors.isEmpty)
    }

    @Test("成功后又失败，错误重新出现")
    func reappearsAfterFailure() {
        var tracker = MonitorIssueTracker()
        tracker.recordSuccess(repo: "a/b", at: t0)
        #expect(tracker.activeErrors.isEmpty)

        tracker.recordFailure(repo: "a/b", error: .rateLimited(resetAt: nil), at: t0.addingTimeInterval(5))
        #expect(tracker.activeErrors["a/b"] != nil)
    }

    @Test("取消不计为错误")
    func ignoresCancellation() {
        var tracker = MonitorIssueTracker()
        tracker.recordFailure(repo: "a/b", error: .cancelled, at: t0)
        #expect(tracker.activeErrors.isEmpty)
    }

    @Test("多个仓库互不影响")
    func isolatedPerRepo() {
        var tracker = MonitorIssueTracker()
        tracker.recordFailure(repo: "a/b", error: .offline, at: t0)
        tracker.recordFailure(repo: "c/d", error: .server(status: 500), at: t0)

        tracker.recordSuccess(repo: "a/b", at: t0.addingTimeInterval(1))

        #expect(tracker.activeErrors["a/b"] == nil)
        #expect(tracker.activeErrors["c/d"] != nil)
        #expect(tracker.activeErrors.count == 1)
    }

    @Test("仓库被移除后错误清空")
    func pruneRemovedRepos() {
        var tracker = MonitorIssueTracker()
        tracker.recordFailure(repo: "a/b", error: .offline, at: t0)
        tracker.recordFailure(repo: "c/d", error: .offline, at: t0)

        tracker.prune(keeping: ["a/b"])

        #expect(tracker.activeErrors.keys.sorted() == ["a/b"])
    }

    @Test("最需要处理的错误排在最前")
    func severityOrdering() {
        #expect(MonitorIssueTracker.severity(.unauthorized) < MonitorIssueTracker.severity(.rateLimited(resetAt: nil)))
        #expect(MonitorIssueTracker.severity(.rateLimited(resetAt: nil)) < MonitorIssueTracker.severity(.offline))
        #expect(MonitorIssueTracker.severity(.offline) < MonitorIssueTracker.severity(.server(status: 500)))
        #expect(MonitorIssueTracker.severity(.cancelled) > MonitorIssueTracker.severity(.server(status: 500)))
    }

    @Test("mostActionable 返回未授权")
    func mostActionable() {
        var tracker = MonitorIssueTracker()
        tracker.recordFailure(repo: "a/b", error: .offline, at: t0)
        tracker.recordFailure(repo: "c/d", error: .unauthorized, at: t0)
        #expect(tracker.mostActionable == .unauthorized)
    }
}
