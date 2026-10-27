import SwiftUI

struct AddRepoSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var error: AppError?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("chenyynx/Agents-Anywhere", text: $input)
                        .font(.system(size: 14, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("支持私有仓库，Token 需要有该仓库的 Actions 读权限。")
                }

                if let error {
                    Section {
                        Text(error.localizedDescription)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("添加仓库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        Task { await submit() }
                    }
                    .disabled(input.isEmpty || isWorking)
                }
            }
        }
        .presentationDetents([.height(300)])
    }

    private func submit() async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            try await environment.repos.add(input)
            await environment.monitor.refreshNow()
            dismiss()
        } catch {
            self.error = AppError.map(error)
        }
    }
}
