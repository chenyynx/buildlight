import UIKit
import SwiftUI
import SwiftData

struct SettingsView: View {
    /// 由 RootTabView 注入：点了「已下载的包」直接切到产物 Tab。
    var onOpenPackages: () -> Void = {}
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    @AppStorage(NotificationService.storageKey) private var notifyBuildEvents = true
    @State private var notificationDenied = false
    /// 系统授权状态。开关的真实值 = 用户意愿 && 系统已授权，
    /// 否则会出现「开关显示开、但根本收不到」的谎报状态。
    @State private var notificationAuthorized = false
    /// 主屏图标。系统是唯一事实源，这里只做镜像。
    @State private var appIcon: AppIconOption = .current
    @AppStorage(BackgroundKeepAlive.storageKey) private var keepAliveEnabled = true
    @State private var showingSignOutConfirmation = false
    @State private var isSyncing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let login = environment.session.user?.login {
                        Text("已连接 \(login)")
                            .scaledFont(size: 12.5)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DS.pad)
                            .padding(.bottom, 4)
                    }

                    SectionLabel("外观")
                    GlassSurface(level: .panel, cornerRadius: Metrics.radiusL) {
                        VStack(alignment: .leading, spacing: 14) {
                            AccentThemePicker(selection: themeBinding)
                            GlassHairline()
                            AppIconPicker(selection: $appIcon)
                            GlassHairline()
                            motionRow
                        }
                    }
                    .padding(.horizontal, DS.pad)

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
                                tint: accent.primary,
                                title: "同步全部仓库",
                                value: isSyncing ? "同步中" : "\(visibleCount) 个"
                            )
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(isSyncing)

                        Hairline(leading: 54)

                        FunctionRow(
                            systemImage: "antenna.radiowaves.left.and.right",
                            tint: accent.primary,
                            title: "轮询状态",
                            value: environment.monitor.isRefreshing ? "刷新中" : "空闲"
                        )

                        Hairline(leading: 54)

                        NavigationLink(value: SettingsRoute.repos) {
                            FunctionRow(
                                systemImage: "list.bullet.rectangle",
                                tint: accent.primary,
                                title: "管理仓库",
                                value: "增删 · 排序 · 限定工作流",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(PressableStyle())
                    }

                    SectionLabel("通知")
                    GroupBox2 {
                        HStack(spacing: 12) {
                            glyph("bell.badge.fill", tint: StatusTone.failed)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("构建结束提醒")
                                    .scaledFont(size: 15)
                                if !notificationAuthorized {
                                    Text("系统未授权，收不到任何提醒")
                                        .font(Type.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: notifyBinding)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)

                        Hairline(leading: 54)
                        NavigationLink(value: SettingsRoute.notificationDiagnostics) {
                            FunctionRow(
                                systemImage: "waveform.badge.magnifyingglass",
                                tint: .gray,
                                title: "通知诊断",
                                value: notificationAuthorized ? "正常" : "未授权",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(PressableStyle())

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
                                    title: "去系统设置开启通知",
                                    showsChevron: true
                                )
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }

                    SectionLabel("后台")
                    GroupBox2 {
                        HStack(spacing: 12) {
                            glyph("waveform", tint: accent.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("后台持续监控")
                                    .font(.scaledFont(size: 15))
                                Text("构建进行中时保持 App 活跃，结束后自动收紧")
                                    .font(Type.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: $keepAliveEnabled)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                    }

                    SectionLabel("存储")
                    GroupBox2 {
                        // 不再进第二套缓存页：和在「产物」Tab 里看到的是同一批文件，
                        // 两套 UI 的删除/清空行为还不一致，容易误操作。
                        Button {
                            onOpenPackages()
                        } label: {
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
                        .scaledFont(size: 11)
                        .foregroundStyle(.quaternary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 26)
                }
                .padding(.bottom, Metrics.tabBarClearance)
            }
            .scrollIndicators(.hidden)
            .background(PaperBackground())
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .repos: RepoListView()
                case .notificationDiagnostics: NotificationDiagnosticsView()
                }
            }
            .confirmationDialog("退出后需要重新填写 Token", isPresented: $showingSignOutConfirmation) {
                Button("退出登录", role: .destructive) {
                    environment.monitor.stop()
                    environment.session.signOut()
                }
                Button("取消", role: .cancel) {}
            }
            .task {
                await refreshNotificationState()
                appIcon = AppIconOption.current
            }
            .onChange(of: scenePhase) { _, phase in
                // 从设置里改回图标后，回来要跟系统的真实状态对齐。
                guard phase == .active else { return }
                appIcon = AppIconOption.current
            }
        }
    }

    // MARK: 外观

    /// 主题绑定走 store，而不是 `@AppStorage`——
    /// `@Observable` 类里用 `@AppStorage` 不会触发视图刷新。
    private var themeBinding: Binding<AccentTheme> {
        Binding(
            get: { environment.appearance.theme },
            set: { environment.appearance.theme = $0 }
        )
    }

    private var accent: Accent {
        environment.appearance.accent(for: colorScheme)
    }

    private var motionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path")
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(accent.primary, in: .rect(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text("减弱动效")
                    .scaledFont(size: 15)
                Text("关掉循环动画和入场位移")
                    .scaledFont(size: 11)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: motionBinding)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private var motionBinding: Binding<Bool> {
        Binding(
            get: { environment.appearance.reduceMotionEnabled },
            set: { environment.appearance.reduceMotionEnabled = $0 }
        )
    }

    // MARK: 杂项

    private func glyph(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .scaledFont(size: 13, weight: .semibold)
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(tint, in: .rect(cornerRadius: 7))
    }

    private var visibleCount: Int {
        repos.count { !$0.isHidden }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    /// 开关绑定。
    ///
    /// 打开时如果系统还没授权，先走一次授权请求；被拒就把开关退回关，
    /// 不留一个「看着是开的但其实收不到」的状态。
    private var notifyBinding: Binding<Bool> {
        Binding(
            get: { notifyBuildEvents && notificationAuthorized },
            set: { wantsOn in
                guard wantsOn else {
                    notifyBuildEvents = false
                    return
                }
                Task {
                    let granted = await NotificationService.shared.requestAuthorization()
                    notificationAuthorized = granted
                    notificationDenied = !granted
                    notifyBuildEvents = granted
                }
            }
        )
    }

    private func refreshNotificationState() async {
        await NotificationService.shared.refreshStatus()
        notificationDenied = NotificationService.shared.isDenied
        notificationAuthorized = NotificationService.shared.isAuthorized
    }

    private func sync() async {
        isSyncing = true
        defer { isSyncing = false }
        try? await environment.repos.syncAll()
        await environment.monitor.refreshNow()
    }
}
