import SwiftUI

/// 首次进入：只要一个 Token。
///
/// 刻意做成单屏单任务——登录是唯一阻塞项，
/// 多一步说明就多一次流失。
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accent) private var accent

    @State private var token = ""
    @State private var error: AppError?
    @State private var isWorking = false
    @State private var statusText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero

                    GlassSurface(level: .panel, cornerRadius: Metrics.radiusL) {
                        VStack(alignment: .leading, spacing: 14) {
                            SecureField("github_pat_…", text: $token)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.body.monospaced())
                                .padding(.horizontal, 12)
                                .frame(height: 44)
                                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))

                            if let error {
                                Text(error.localizedDescription)
                                    .font(.footnote)
                                    .foregroundStyle(StatusTone.failed)
                            }

                            PrimaryButton(title: isWorking ? statusText : "连接 GitHub") {
                                submit()
                            }
                            .disabled(token.isEmpty || isWorking)
                            .opacity(token.isEmpty ? 0.5 : 1)
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, DS.pad)
                    .padding(.top, 20)

                    SectionLabel("需要的权限")
                    VStack(alignment: .leading, spacing: 8) {
                        permissionRow("hammer", "Actions: Read")
                        permissionRow("doc.text", "Contents: Read")
                        permissionRow("info.circle", "Metadata: Read")
                    }
                    .padding(.horizontal, DS.pad + 4)

                    Text("Token 只存在本机的 Keychain，不会离开这台设备。")
                        .scaledFont(size: 11.5)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, DS.pad)
                        .padding(.top, 18)
                }
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
            .background(PaperBackground())
            .navigationTitle("连接 GitHub")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await environment.session.refreshIdentityIfNeeded() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BuildLight")
                .scaledFont(size: 30, weight: .bold)
                .tracking(-0.8)
            Text("盯着自己的几个仓库看构建：一屏知道谁在跑、有没有包可以取。")
                .scaledFont(size: 14)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DS.pad)
        .padding(.top, 18)
    }

    private func permissionRow(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon)
            .scaledFont(size: 13)
            .foregroundStyle(.secondary)
    }

    private func submit() {
        isWorking = true
        error = nil
        statusText = "验证中…"
        Task {
            defer { isWorking = false }
            do {
                try await environment.session.signIn(with: token)
                // 登录成功不等于能用：不把仓库拉下来，首页就是一片空白，
                // 用户还得自己去设置里找「同步全部仓库」。
                statusText = "同步仓库…"
                try? await environment.repos.syncAll()
                environment.monitor.start()
                await environment.monitor.refreshNow()
            } catch {
                self.error = AppError.map(error)
            }
        }
    }
}
