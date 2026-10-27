import SwiftUI

/// 首次启动：录入 PAT。
struct TokenSetupView: View {
    @Environment(BuildStore.self) private var store
    @State private var token = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("github_pat_…", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Personal Access Token")
                } footer: {
                    Text("Fine-grained token，需要 Actions: Read、Contents: Read、Metadata: Read 权限。Token 只存在本机 Keychain。")
                }

                if let error {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if working { ProgressView().padding(.trailing, 6) }
                            Text(working ? "验证中…" : "保存并开始")
                            Spacer()
                        }
                    }
                    .disabled(token.isEmpty || working)
                }
            }
            .navigationTitle("连接 GitHub")
        }
    }

    private func submit() async {
        working = true
        error = nil
        defer { working = false }
        do {
            try await store.setToken(token)
            store.startPolling()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// 添加仓库。
struct AddRepoSheet: View {
    @Binding var isPresented: Bool
    @Binding var adding: Bool
    @Environment(BuildStore.self) private var store
    @State private var input = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("owner/repo", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } footer: {
                    Text("支持私有仓库，Token 需要有该仓库的读权限。")
                }
                if let error {
                    Section { Text(error).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("添加仓库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { Task { await submit() } }
                        .disabled(input.isEmpty || adding)
                }
            }
        }
    }

    private func submit() async {
        adding = true
        error = nil
        defer { adding = false }
        do {
            try await store.addRepo(fullName: input)
            isPresented = false
        } catch {
            self.error = error.localizedDescription
        }
    }
}
