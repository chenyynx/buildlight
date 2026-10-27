import Foundation
import SwiftData

enum PersistenceStack {
    static let schema = Schema([
        RepoRecord.self,
        RunRecord.self,
        ArtifactRecord.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
