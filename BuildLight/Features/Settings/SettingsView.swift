import UIKit
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openURL) private var openURL
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    @AppStorage(NotificationService.storageKey) private var notifyBuildEvents = true
    @State private var notificationDenied = false
    @State private var showingSignOutConfirmation = false
    @State private var isSyncing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeader(
                        title: "设置",
                        subtitle: environment.session.user?.login.map { "已连接 \($0)" } ?? "已连接"
                    )

                    SectionLabel("账号")
                    GroupBox2 {
                        FunctionRow(
                            systemImage: "person.fill",
                            tint: .blue,
                            title: "登录身份",
                            value: environment.session.user?.login ?? "—"
                        )
                        Hairline(leading: 54)
                        Button {
                            showingSignOutConfirmation = true
                        } label: {
                            FunctionRow(
                                systemImage: "rectangle.portrait.and.arrow.right",
                                tint: StatusTone.failed,
                                title: "退出登录"
                            )
                        }
                        .buttonStyle(PressableStyle())
                    }

                    SectionLabel("仓库")
                    GroupBox2 {
                        Button {
                            Task { await sync() }
                        } label: {
                            FunctionRow(
                                systemImage: "arrow.triangle.2.circlepath",
                                tint: Accent.primary,
                                title: "同步全部仓库",
                                value: isSyncing ? "同步中" : "\(visibleCount) 个"
                            )
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(isSyncing)

                        Hairline(leading: 54)

                        FunctionRow(
                            systemImage: "antenna.radiowaves.left.and.right",
                            tint: StatusTone.running,
                            title: "轮询状态",
                            value: environment.monitor.isRefreshing ? "刷新中" : "空闲"
                        )
                    }

                    SectionLabel("通知")
                    GroupBox2 {
                        HStack(spacing: 12) {
                            glyph("bell.badge.fill", tint: StatusTone.failed)
                            Text("构建结束提醒")
                                .font(.system(size: 15))
                            Spacer(minLength: 8)
                            Toggle("", isOn: $notifyBuildEvents)
                                .labelsHidden()
                                .onChange(of: notifyBuildEvents) { _, enabled in
                                    guard enabled else { return }
                                    Task {
                                        let granted = await NotificationService.shared.requestAuthorization()
                                        notificationDenied = !granted
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)

                        if notificationDenied {
                            Hairline(leading: 54)
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            } label: {
                                FunctionRow(
                                    systemImage: "exclamationmark.triangle.fill",
                                    tint: StatusTone.failed,
                                    title: "系统未授权通知",
                                    showsChevron: true
                                )
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }

                    SectionLabel("存储")
                    GroupBox2 {
                        NavigationLink(value: SettingsRoute.cache) {
                            FunctionRow(
                                systemImage: "internaldrive.fill",
                                tint: .orange,
                                title: "已下载的包",
                                value: "\(environment.cache.entries.count) 个 · \(environment.cache.totalSizeText)",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(PressableStyle())
                    }

                    SectionLabel("关于")
                    GroupBox2 {
                        FunctionRow(
                            systemImage: "info.circle.fill",
                            tint: .gray,
                            title: "版本",
                            value: appVersion
                        )
                    }

                    Text("BuildLight · 只盯 iPhone 上用得到的那些构建")
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 26)
                }
                .padding(.bottom, Metrics.tabBarClearance)
            }
            .scrollIndicators(.hidden)
            .background(PaperBackground())
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .cache: CacheView()
                }
            }
            .confirmationDialog("退出后需要重新填写 Token", isPresented: $showingSignOutConfirmation) {
                Button("退出登录", role: .destructive) {
                    environment.monitor.stop()
                    environment.session.signOut()
                }
                Button("取消", role: .cancel) {}
            }
            .task { await refreshNotificationState() }
        }
    }

    private func glyph(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(tint, in: .rect(cornerRadius: 7))
    }

    private var visibleCount: Int {
        repos.filter { !$0.isHidden }.count
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func refreshNotificationState() async {
        await NotificationService.shared.refreshStatus()
        notificationDenied = NotificationService.shared.isDenied
    }

    private func sync() async {
        isSyncing = true
        defer { isSyncing = false }
        try? await environment.repos.syncAll()
        await environment.monitor.refreshNow()
    }
}
