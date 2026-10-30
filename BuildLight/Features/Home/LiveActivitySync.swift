import SwiftData
import SwiftUI

/// 把「谁在跑」同步到锁屏实时活动。
/// 挂零尺寸视图，不参与布局；签名不变就不触发同步。
struct LiveActivitySync: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task(id: signature) { await push() }
    }

    private var signature: String {
        let theme = environment.appearance.theme.rawValue
        return theme + "#" + repos
            .map { "\($0.fullName):\($0.activeRunCount):\($0.latestStartedAt?.timeIntervalSince1970 ?? 0)" }
            .joined(separator: "|")
    }

    private func push() async {
        let running = repos
            .filter(\.isRunning)
            .prefix(20)
            .map { repo in
                RunningBuild(
                    id: repo.fullName,
                    repo: repo.displayName,
                    branch: repo.latestBranch ?? "",
                    startedAt: repo.latestStartedAt ?? .now
                )
            }
        let failed = repos.filter(\.latestFailed).count

        let theme = environment.appearance.theme
        await BuildActivityController.shared.sync(
            running: Array(running),
            finishedCount: 0,
            failedCount: failed,
            accentLightHex: theme.lightHex,
            accentDarkHex: theme.darkHex
        )
    }
}
