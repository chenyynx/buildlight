import Foundation
import SwiftData

enum PersistenceStack {
    /// 每次取用都新建，避免把非 Sendable 的 Schema 暴露成全局状态。
    static var schema: Schema {
        Schema([
            RepoRecord.self,
            RunRecord.self,
            ArtifactRecord.self
        ])
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
