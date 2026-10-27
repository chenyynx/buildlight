import Foundation
import Observation
import SwiftData

/// 依赖容器。全部服务在这里组装一次，视图只拿它。
@MainActor
@Observable
final class AppEnvironment {
    let container: ModelContainer
    let context: ModelContext
    let session: GitHubSession
    let monitor: BuildMonitor
    let packages: PackageService
    let repos: RepoService

    init(container: ModelContainer) {
        self.container = container

        let context = ModelContext(container)
        context.autosaveEnabled = true
        self.context = context

        let session = GitHubSession()
        self.session = session
        self.monitor = BuildMonitor(context: context, session: session)
        self.packages = PackageService(session: session)
        self.repos = RepoService(context: context, session: session)
    }
}
