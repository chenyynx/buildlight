import SwiftUI

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var colorScheme

    @State private var token = ""
    @State private var error: AppError?
    @State private var isWorking = false

    private var palette: DesignPalette { .resolve(colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MicroLabel(text: "Build light", color: palette.textTertiary)
                    .padding(.top, 40)

                Text("连接\nGitHub")
                    .font(.display(40))
                    .foregroundStyle(palette.textPrimary)
                    .padding(.top, 10)

                Text("用一个 Fine-grained Token 读取你自己仓库的构建状态。Token 只存在本机的 Keychain 里。")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textSecondary)
                    .lineSpacing(4)
                    .padding(.top, 14)

                SecureField("github_pat_…", text: $token)
                    .font(.system(size: 13, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(palette.surface, in: .rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(palette.hairline, lineWidth: 0.5)
                    }
                    .padding(.top, 24)

                if let error {
                    Text(error.localizedDescription)
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.failure)
                        .padding(.top, 10)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if isWorking { ProgressView().controlSize(.small).padding(.trailing, 6) }
                        Text(isWorking ? "验证中…" : "开始使用")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 15)
                    .background(palette.accentGradient, in: .capsule)
                    .opacity(token.isEmpty || isWorking ? 0.5 : 1)
                }
                .disabled(token.isEmpty || isWorking)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 8) {
                    step("1", "GitHub → Settings → Developer settings → Personal access tokens")
                    step("2", "Fine-grained token，选中要看的仓库")
                    step("3", "权限勾 Actions: Read、Contents: Read、Metadata: Read")
                }
                .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(palette.background)
    }

    private func step(_ index: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(index)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.textTertiary)
                .frame(width: 12, alignment: .leading)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func submit() async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            try await environment.session.signIn(with: token)
            environment.monitor.start()
            await environment.monitor.refreshNow()
        } catch {
            self.error = AppError.map(error)
        }
    }
}
