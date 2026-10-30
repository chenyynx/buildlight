import SwiftUI

/// 限定只看某个工作流。
///
/// 一个仓库常有多个 workflow（CI / Release / Nightly），
/// 首页只看「最近一次」时会被无关的 workflow 盖住。
/// 这里让用户选一个，首页和详情页都只认它。
struct RepoWorkflowPicker: View {
    @Environment(AppEnvironment.self) private var environment
    let repo: RepoRecord

    @State private var workflows: [String] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Button {
                    environment.repos.setWorkflowFilter(nil, for: repo)
                } label: {
                    row(title: "全部工作流", subtitle: "显示这个仓库的所有构建", selected: repo.workflowFilter == nil)
                }
                .buttonStyle(.plain)
            }

            Section {
                if isLoading {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("读取中…").foregroundStyle(.secondary)
                    }
                } else if workflows.isEmpty {
                    Text(error ?? "这个仓库没有可用的工作流")
                        .font(Type.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workflows, id: \.self) { name in
                        Button {
                            environment.repos.setWorkflowFilter(name, for: repo)
                        } label: {
                            row(
                                title: name,
                                subtitle: nil,
                                selected: repo.workflowFilter == name
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("工作流")
            }
        }
        .navigationTitle(repo.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func row(title: String, subtitle: String?, selected: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Type.body)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(Type.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if selected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(.rect)
        .padding(.vertical, 2)
    }

    private func load() async {
        guard let client = environment.session.client else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            workflows = try await client.workflows(owner: repo.owner, repo: repo.name)
            error = nil
        } catch {
            self.error = AppError.map(error).localizedDescription
        }
    }
}
