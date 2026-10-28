import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    @State private var showingSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("账号") {
                    LabeledContent("登录身份", value: environment.session.user?.login ?? "已连接")
                    Button("退出登录", role: .destructive) {
                        showingSignOutConfirmation = true
                    }
                }

                Section {
                    ForEach(repos) { repo in
                        NavigationLink(value: repo.fullName) {
                            Text(repo.fullName)
                        }
                        .swipeActions {
                            Button("移除", role: .destructive) {
                                environment.repos.remove(repo)
                            }
                        }
                    }
                    Button("同步全部仓库", systemImage: "arrow.triangle.2.circlepath") {
                        Task { try? await environment.repos.syncAll() }
                    }
                } header: {
                    Text("跟踪的仓库（\(repos.count)）")
                } footer: {
                    Text("左滑可以移除。")
                }

                Section("缓存") {
                    NavigationLink {
                        CacheView()
                    } label: {
                        LabeledContent("已下载的包", value: "\(environment.cache.entries.count) 个 · \(environment.cache.totalSizeText)")
                    }
                    LabeledContent("轮询状态", value: environment.monitor.isRefreshing ? "刷新中" : "空闲")
                    if let last = environment.monitor.lastRefreshAt {
                        LabeledContent("上次刷新", value: last.formatted(date: .omitted, time: .standard))
                    }
                }

                Section("关于") {
                    LabeledContent("版本", value: appVersion)
                }
            }
            .navigationTitle("设置")
            .navigationDestination(for: String.self) { fullName in
                if let repo = repos.first(where: { $0.fullName == fullName }) {
                    RepoDetailView(repo: repo)
                }
            }
            .confirmationDialog("退出后需要重新填写 Token", isPresented: $showingSignOutConfirmation) {
                Button("退出登录", role: .destructive) {
                    environment.monitor.stop()
                    environment.session.signOut()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
