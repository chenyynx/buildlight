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
    let cache: CacheStore
    let repos: RepoService
    /// 外观（强调色、动效开关）。全局唯一，App 启动时读一次。
    let appearance: AppearanceStore

    init(container: ModelContainer) {
        self.container = container

        let context = ModelContext(container)
        context.autosaveEnabled = true
        self.context = context

        let session = GitHubSession()
        self.session = session
        let cache = CacheStore()
        self.cache = cache
        let packages = PackageService(session: session, cache: cache)
        self.packages = packages
        self.monitor = BuildMonitor(context: context, session: session, packages: packages)
        self.repos = RepoService(context: context, session: session)
        self.appearance = AppearanceStore()

        // 启动时把磁盘上的半截下载进度读进内存一次，
        // 之后卡片 body 里只查内存，不再碰磁盘。
        let artifactIDs = (try? context.fetch(FetchDescriptor<ArtifactRecord>()))?.map(\.id) ?? []
        self.packages.primeDiskProgress(artifactIDs: artifactIDs)
    }
}
