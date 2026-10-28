import SwiftUI

extension RepositorySummary: Identifiable {
    var id: String { fullName }
}

/// 用原生 List 列出 token 能访问的仓库，勾选即可加入。
/// 不需要用户记住 owner/repo，也不该让他们手打。
struct RepoPickerView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    /// 首次配置时为 true：加完直接进入主界面。
    var isOnboarding: Bool = false

    @State private var repositories: [RepositorySummary] = []
    @State private var selected: Set<String> = []
    @State private var isLoading = true
    @State private var error: AppError?
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("正在读取仓库…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    ContentUnavailableView {
                        Label("读取失败", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("重试") { Task { await load() } }
                    }
                } else if repositories.isEmpty {
                    ContentUnavailableView(
                        "没有可访问的仓库",
                        systemImage: "shippingbox",
                        description: Text("去 GitHub 检查这个 Token 的 Repository access 是否包含要看的仓库")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("选择仓库")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "搜索仓库")
            .toolbar {
                if isOnboarding {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(addButtonTitle) { add() }
                            .disabled(selected.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(addButtonTitle) { add() }
                            .disabled(selected.isEmpty)
                    }
                }
            }
            .task { await load() }
        }
    }

    private var list: some View {
        List(filtered) { repository in
            Button {
                toggle(repository)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(repository.fullName)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if let pushed = repository.pushedAt {
                            Text("最近推送 \(relativeText(pushed))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if repository.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: selected.contains(repository.fullName) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected.contains(repository.fullName) ? Color.accentColor : Color.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.insetGrouped)
    }

    private var addButtonTitle: String {
        selected.isEmpty ? "添加" : "添加 \(selected.count) 个"
    }

    private var filtered: [RepositorySummary] {
        guard !query.isEmpty else { return repositories }
        return repositories.filter { $0.fullName.localizedCaseInsensitiveContains(query) }
    }

    private func relativeText(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    private func toggle(_ repository: RepositorySummary) {
        if selected.contains(repository.fullName) {
            selected.remove(repository.fullName)
        } else {
            selected.insert(repository.fullName)
        }
    }

    private func load() async {
        guard let client = environment.session.client else {
            error = .unauthorized
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            repositories = try await client.repositories()
            error = nil
        } catch {
            self.error = AppError.map(error)
        }
    }

    private func add() {
        for summary in repositories where selected.contains(summary.fullName) {
            environment.repos.add(summary)
        }
        Task { await environment.monitor.refreshNow() }
        if !isOnboarding { dismiss() }
    }
}
