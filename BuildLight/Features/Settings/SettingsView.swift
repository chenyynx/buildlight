import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    @State private var showingSignOutConfirmation = false
    @State private var isSyncing = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                repositoriesSection
                cacheSection
                aboutSection
            }
            .navigationTitle("设置")
            .confirmationDialog("退出后需要重新填写 Token", isPresented: $showingSignOutConfirmation) {
                Button("退出登录", role: .destructive) {
                    environment.monitor.stop()
                    environment.session.signOut()
                }
                Button("取消", role: .cancel) {}
            }
            .navigationDestination(for: String.self) { fullName in
                if let repo = repos.first(where: { $0.fullName == fullName }) {
                    RepoDetailView(repo: repo)
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .cache: CacheView()
                }
            }
        }
    }

    private var accountSection: some View {
        Section("账号") {
            LabeledContent {
                Text(environment.session.user?.login ?? "已连接")
                    .foregroundStyle(.secondary)
            } label: {
                Label {
                    Text("登录身份")
                } icon: {
                    SettingGlyph(systemImage: "person.fill")
                }
            }

            LabeledContent {
                Text("\(repos.filter { !$0.isHidden }.count) 个")
                    .foregroundStyle(.secondary)
            } label: {
                Label {
                    Text("正在跟踪")
                } icon: {
                    SettingGlyph(systemImage: "square.stack.3d.up.fill", tint: .teal)
                }
            }

            Button {
                showingSignOutConfirmation = true
            } label: {
                Label {
                    Text("退出登录").foregroundStyle(.red)
                } icon: {
                    SettingGlyph(systemImage: "rectangle.portrait.and.arrow.right", tint: .red)
                }
            }
        }
    }

    private var repositoriesSection: some View {
        Section {
            Button {
                Task { await sync() }
            } label: {
                Label {
                    HStack {
                        Text("同步全部仓库")
                        Spacer()
                        if isSyncing { ProgressView().controlSize(.small) }
                    }
                } icon: {
                    SettingGlyph(systemImage: "arrow.triangle.2.circlepath", tint: .blue)
                }
            }
            .disabled(isSyncing)
        } header: {
            Text("仓库")
        } footer: {
            Text("同步会拉取 Token 能访问的全部仓库，自动加入看板。")
        }
    }

    private var cacheSection: some View {
        Section("缓存") {
            NavigationLink(value: SettingsRoute.cache) {
                row(
                    glyph: "internaldrive.fill",
                    tint: .orange,
                    title: "已下载的包",
                    value: "\(environment.cache.entries.count) 个 · \(environment.cache.totalSizeText)"
                )
            }

            row(
                glyph: "antenna.radiowaves.left.and.right",
                tint: .green,
                title: "轮询状态",
                value: environment.monitor.isRefreshing ? "刷新中" : "空闲"
            )

            if let last = environment.monitor.lastRefreshAt {
                row(
                    glyph: "clock.fill",
                    tint: .gray,
                    title: "上次刷新",
                    value: last.formatted(date: .omitted, time: .standard)
                )
            }
        }
    }

    private var aboutSection: some View {
        Section("关于") {
            row(glyph: "info.circle.fill", tint: .gray, title: "版本", value: appVersion)
        }
    }

    private func row(glyph: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: Metrics.s) {
            SettingGlyph(systemImage: glyph, tint: tint)
            Text(title)
            Spacer(minLength: Metrics.s)
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func sync() async {
        isSyncing = true
        defer { isSyncing = false }
        try? await environment.repos.syncAll()
        await environment.monitor.refreshNow()
    }
}
