import SwiftUI

/// 仓库卡片的手势层。
///
/// 交互设计：
/// - 长按：快捷菜单（重跑 / 取消 / 隐藏仓库）——远程操作不必进详情页
/// - 点击：进详情
///
/// 为什么用长按菜单而不是侧滑：
/// 侧滑 `swipeActions` 只在 `List` 里生效，而首页为了卡片动画用的是
/// `ScrollView` + `LazyVStack`。与其在两套列表里维护两套手势，
/// 不如统一用长按菜单——在任何容器下行为一致。
struct RepoCardContainer<Content: View>: View {
    let repo: RepoRecord
    @ViewBuilder var content: Content

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        content
            .contentShape(.rect)
            .contextMenu {
                if repo.isRunning {
                    Button("取消运行", systemImage: "xmark", role: .destructive) {
                        cancel()
                    }
                } else {
                    Button("重新运行", systemImage: "arrow.clockwise") {
                        rerun()
                    }
                }

                Button("隐藏这个仓库", systemImage: "eye.slash") {
                    environment.repos.setHidden(true, for: repo)
                }
            }
    }

    private func rerun() {
        guard let client = environment.session.client, let runID = repo.latestRunID else { return }
        Task { try? await client.rerun(owner: repo.owner, repo: repo.name, runID: runID) }
    }

    private func cancel() {
        guard let client = environment.session.client, let runID = repo.latestRunID else { return }
        Task { try? await client.cancel(owner: repo.owner, repo: repo.name, runID: runID) }
    }
}
