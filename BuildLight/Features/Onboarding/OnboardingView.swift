import SwiftUI

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var token = ""
    @State private var error: AppError?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("github_pat_…", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                } header: {
                    Text("Personal Access Token")
                } footer: {
                    Text("Fine-grained token，权限勾选 Actions: Read、Contents: Read、Metadata: Read。Token 只存在本机的 Keychain。")
                }

                if let error {
                    Section {
                        Text(error.localizedDescription)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if isWorking {
                                ProgressView().controlSize(.small)
                                    .padding(.trailing, 6)
                            }
                            Text(isWorking ? "验证中…" : "继续")
                            Spacer()
                        }
                    }
                    .disabled(token.isEmpty || isWorking)
                }

                Section("需要的权限") {
                    Label("Actions: Read", systemImage: "hammer")
                    Label("Contents: Read", systemImage: "doc.text")
                    Label("Metadata: Read", systemImage: "info.circle")
                }
            }
            .navigationTitle("连接 GitHub")
        }
        .task { await environment.session.refreshIdentityIfNeeded() }
    }

    private func submit() {
        isWorking = true
        error = nil
        Task {
            defer { isWorking = false }
            do {
                try await environment.session.signIn(with: token)
                environment.monitor.start()
            } catch {
                self.error = AppError.map(error)
            }
        }
    }
}
