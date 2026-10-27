import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    private var palette: Palette { .resolve(colorScheme) }

    @State private var confirmingSignOut = false

    var body: some View {
        Form {
            Section("账号") {
                LabeledContent("登录身份", value: environment.session.user?.login ?? "已连接")
                Button("退出登录", role: .destructive) { confirmingSignOut = true }
            }

            Section {
                ForEach(repos) { repo in
                    NavigationLink {
                        RepoDetailView(repo: repo)
                    } label: {
                        Text(repo.fullName)
                            .font(.system(size: 14, design: .monospaced))
                    }
                    .swipeActions {
                        Button("移除", role: .destructive) {
                            environment.repos.remove(repo)
                        }
                    }
                }
            } header: {
                Text("跟踪的仓库（\(repos.count)）")
            } footer: {
                Text("左滑可以移除。")
            }

            Section("缓存") {
                Button("清理已下载的产物") {
                    environment.packages.purgeReadyFiles()
                }
                LabeledContent("轮询状态", value: environment.monitor.isRefreshing ? "刷新中" : "空闲")
                if let last = environment.monitor.lastRefreshAt {
                    LabeledContent("上次刷新", value: last.formatted(date: .omitted, time: .standard))
                }
            }

            Section("关于") {
                LabeledContent("版本", value: appVersion)
                LabeledContent("配色", value: "跟随系统")
            }
        }
        .editorialBackground(palette)
        .navigationTitle("设置")
        .confirmationDialog("退出后需要重新填写 Token", isPresented: $confirmingSignOut) {
            Button("退出登录", role: .destructive) {
                environment.monitor.stop()
                environment.session.signOut()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
