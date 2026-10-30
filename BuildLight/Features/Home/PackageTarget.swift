import Foundation

/// 取包只需要这几个字段，不必把 SwiftData 的产物对象带进每一帧的视图计算。
struct PackageTarget: Hashable {
    let id: Int
    let name: String
    let archiveURL: URL
    /// 仓库短名（如 buildlight）。用于生成可读文件名。
    var repoName: String = ""
    /// 构建号（run_number）。
    var runNumber: Int = 0
    /// 分支名。
    var branch: String = ""
    /// 工作流名。
    var workflowName: String = ""

    init(
        id: Int,
        name: String,
        archiveURL: URL,
        repoName: String = "",
        runNumber: Int = 0,
        branch: String = "",
        workflowName: String = ""
    ) {
        self.id = id
        self.name = name
        self.archiveURL = archiveURL
        self.repoName = repoName
        self.runNumber = runNumber
        self.branch = branch
        self.workflowName = workflowName
    }

    /// 落地后的文件名。
    ///
    /// 之前的命名是 `"\(artifactID)-\(原文件名)"`，
    /// 到了全能签里显示成 `12993131911-BuildLight-unsigned.ipa`——
    /// 开头一长串数字，几个包放在一起根本分不清谁是谁。
    /// 现在用「仓库-构建号-分支」，全能签列表里一眼能认出来。
    var friendlyFileName: String {
        var parts: [String] = []
        if !repoName.isEmpty { parts.append(repoName) }
        if runNumber > 0 { parts.append("#\(runNumber)") }
        if !branch.isEmpty { parts.append(branch) }
        if parts.isEmpty { parts.append(name) }

        let base = parts.joined(separator: "-")
        return Self.sanitize(base) + ".ipa"
    }

    /// 去掉文件名里非法或容易出问题的字符（分支名常带 `/`）。
    private static func sanitize(_ raw: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = raw.components(separatedBy: illegal).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " -. "))
        return trimmed.isEmpty ? "build" : String(trimmed.prefix(120))
    }
}
