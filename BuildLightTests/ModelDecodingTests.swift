import Testing
import Foundation
@testable import BuildLight

struct ModelDecodingTests {
    private func fixtureData(_ name: String) throws -> Data {
        let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json")
        let unwrapped = try #require(url, "找不到夹具 \(name).json")
        return try Data(contentsOf: unwrapped)
    }

    @Test("解析运行列表并映射状态")
    func decodeRuns() throws {
        let page = try GitHubJSON.makeDecoder().decode(RunsPage.self, from: fixtureData("runs"))
        #expect(page.totalCount == 2)
        #expect(page.workflowRuns.count == 2)

        let running = try #require(page.workflowRuns.first)
        #expect(running.status == .inProgress)
        #expect(running.isActive)
        #expect(running.runNumber == 613)
        #expect(running.headBranch == "feat/beta-absorb-dev-subagent-and-send-fix")
        #expect(running.conclusion == .unknown)

        let done = page.workflowRuns[1]
        #expect(done.status == .completed)
        #expect(!done.isActive)
        #expect(done.conclusion == .success)
    }

    @Test("排队时长 = 真正开始 - 创建")
    func queueDuration() throws {
        let page = try GitHubJSON.makeDecoder().decode(RunsPage.self, from: fixtureData("runs"))
        let running = try #require(page.workflowRuns.first)
        let queue = try #require(running.queueDuration)
        #expect(abs(queue - 26) < 0.5)
    }

    @Test("未知状态不崩，降级为 unknown")
    func unknownStatusFallsBack() {
        #expect(RunStatus(raw: "some_new_state").isActive == false)
        #expect(RunStatus(raw: "queued").isActive == true)
        #expect(RunConclusion(raw: "brand_new_conclusion") == .unknown)
        #expect(RunConclusion(raw: nil) == .unknown)
    }

    @Test("产物体积格式化")
    func artifactSize() throws {
        let json = """
        {"id":1,"name":"BuildLight-unsigned","size_in_bytes":24117248,"expired":false,
         "created_at":"2026-10-27T16:20:00Z","expires_at":"2027-01-25T16:20:00Z",
         "archive_download_url":"https://api.github.com/repos/a/b/actions/artifacts/1/zip"}
        """
        let artifact = try GitHubJSON.makeDecoder().decode(Artifact.self, from: Data(json.utf8))
        #expect(artifact.expired == false)
        #expect(artifact.sizeText.contains("23") || artifact.sizeText.contains("24"))
    }
}

private final class BundleToken {}
