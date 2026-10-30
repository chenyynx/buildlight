import Testing
import Foundation
@testable import BuildLight

/// 产物文件名规则。
///
/// 这串名字会直接出现在签名工具的列表里，
/// 规则错一次用户就得多认一次「这包是哪来的」。
struct PackageTargetTests {
    private func target(
        name: String = "BuildLight-unsigned-ipa",
        repo: String = "buildlight",
        number: Int = 63,
        branch: String = "main"
    ) -> PackageTarget {
        PackageTarget(
            id: 1,
            name: name,
            archiveURL: URL(string: "https://example.com/a.zip")!,
            repoName: repo,
            runNumber: number,
            branch: branch
        )
    }

    @Test("标准命名")
    func standardName() {
        #expect(target().friendlyFileName == "buildlight-#63-main.ipa")
    }

    @Test("分支里的斜杠会被清洗")
    func branchSlash() {
        let t = target(branch: "feat/ui-redesign")
        #expect(t.friendlyFileName == "buildlight-#63-feat-ui-redesign.ipa")
        #expect(!t.friendlyFileName.contains("/"))
    }

    @Test("缺少构建号时不留空段")
    func missingRunNumber() {
        let t = target(number: 0)
        #expect(t.friendlyFileName == "buildlight-main.ipa")
    }

    @Test("字段全空时退回产物名")
    func fallbackToArtifactName() {
        let t = target(name: "MyApp", repo: "", number: 0, branch: "")
        #expect(t.friendlyFileName == "MyApp.ipa")
    }

    @Test("产物名自带 .ipa 不会变成双扩展名")
    func doubleExtension() {
        let t = target(name: "MyApp.ipa", repo: "", number: 0, branch: "")
        #expect(t.friendlyFileName == "MyApp.ipa")
        #expect(!t.friendlyFileName.hasSuffix(".ipa.ipa"))
    }

    @Test("大小写不同的 .IPA 同样剥离")
    func uppercaseExtension() {
        let t = target(name: "MyApp.IPA", repo: "", number: 0, branch: "")
        #expect(t.friendlyFileName == "MyApp.ipa")
    }

    @Test("非法字符全部替换")
    func illegalCharacters() {
        let t = target(repo: "a:b", branch: "c*d?e")
        let name = t.friendlyFileName
        for bad in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"] {
            #expect(!name.contains(bad), "文件名不应包含 \(bad)")
        }
    }

    @Test("超长名字被截断且仍保留扩展名")
    func longName() {
        let t = target(branch: String(repeating: "x", count: 400))
        let name = t.friendlyFileName
        #expect(name.hasSuffix(".ipa"))
        #expect(name.count <= 124)
    }
}
