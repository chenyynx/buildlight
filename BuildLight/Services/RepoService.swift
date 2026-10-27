import Foundation
import Observation
import SwiftData

/// 跟踪仓库的增删改。视图通过 @Query 读，写操作走这里。
@MainActor
@Observable
final class RepoService {
    private let context: ModelContext
    private let session: GitHubSession

    init(context: ModelContext, session: GitHubSession) {
        self.context = context
        self.session = session
    }

    func add(_ fullName: String) async throws {
        let parts = fullName.split(separator: "/")
        guard parts.count == 2 else { throw AppError.notFound }
        let owner = String(parts[0])
        let name = String(parts[1])
        let normalized = "\(owner)/\(name)"

        let existing = try context.fetch(
            FetchDescriptor<RepoRecord>(predicate: #Predicate { $0.fullName == normalized })
        )
        guard existing.isEmpty else { return }

        guard let client = session.client else { throw AppError.unauthorized }
        let summary: RepositorySummary
        do {
            summary = try await client.repository(owner: owner, name: name)
        } catch {
            throw AppError.map(error)
        }

        let count = (try? context.fetchCount(FetchDescriptor<RepoRecord>())) ?? 0
        let record = RepoRecord(owner: owner, name: name, sortIndex: count)
        record.fullName = summary.fullName
        context.insert(record)
        try context.save()
    }

    func remove(_ repo: RepoRecord) {
        context.delete(repo)
        try? context.save()
    }

    func setWorkflowFilter(_ filter: String?, for repo: RepoRecord) {
        repo.workflowFilter = (filter?.isEmpty == true) ? nil : filter
        try? context.save()
    }

    func move(from offsets: IndexSet, to destination: Int, in repos: [RepoRecord]) {
        var ordered = repos
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, repo) in ordered.enumerated() {
            repo.sortIndex = index
        }
        try? context.save()
    }
}
