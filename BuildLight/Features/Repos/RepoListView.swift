import SwiftUI
import SwiftData

/// 仓库管理页。
///
/// `RepoService` 早就有 add / setHidden / remove / move / setWorkflowFilter 五个方法，
/// 但之前一个入口都没有——用户把仓库隐藏了就再也找不回来。
/// 这一页把这些能力补齐：增删、隐藏/恢复、排序、限定工作流。
struct RepoListView: View {
    @Environment(\.accent) private var accent
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \RepoRecord.sortIndex) private var repos: [RepoRecord]

    @State private var showingAddSheet = false
    @State private var newRepoName = ""
    @State private var addError: String?
    @State private var isAdding = false
    @State private var showingHidden = false

    private var visibleRepos: [RepoRecord] {
        repos.filter { !$0.isHidden }
    }

    private var hiddenRepos: [RepoRecord] {
        repos.filter(\.isHidden)
    }

    var body: some View {
        List {
            Section {
                ForEach(visibleRepos) { repo in
                    NavigationLink {
                        RepoWorkflowPicker(repo: repo)
                    } label: {
                        RepoManageRow(repo: repo)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("隐藏", systemImage: "eye.slash") {
                            environment.repos.setHidden(true, for: repo)
                        }
                        .tint(.orange)

                        Button("移除", systemImage: "trash", role: .destructive) {
                            environment.repos.remove(repo)
                        }
                    }
                }
                .onMove { offsets, destination in
                    environment.repos.move(from: offsets, to: destination, in: visibleRepos)
                }
            } header: {
                Text("跟踪中 · \(visibleRepos.count)")
            } footer: {
                // `.onMove` 只在编辑态生效。之前没给编辑入口，
                // 页脚却写着「拖动排序」，等于空头承诺。
                Text("左滑隐藏或移除；点右上角「排序」后可拖动调整顺序。")
            }

            if !hiddenRepos.isEmpty {
                Section {
                    DisclosureGroup("已隐藏 · \(hiddenRepos.count)", isExpanded: $showingHidden) {
                        ForEach(hiddenRepos) { repo in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(repo.displayName)
                                        .font(Type.body)
                                    Text(repo.fullName)
                                        .font(Type.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("恢复") {
                                    environment.repos.setHidden(false, for: repo)
                                }
                                .font(Type.caption.weight(.semibold))
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("仓库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("添加", systemImage: "plus") {
                    showingAddSheet = true
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            addSheet
                .presentationDetents([.height(300)])
        }
        .overlay {
            if repos.isEmpty {
                ContentUnavailableView(
                    "还没有仓库",
                    systemImage: "shippingbox",
                    description: Text("点右上角添加，或在设置里同步全部仓库")
                )
            }
        }
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("owner/repo", text: $newRepoName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                } header: {
                    Text("仓库全名")
                } footer: {
                    if let addError {
                        Text(addError).foregroundStyle(StatusTone.failed)
                    } else {
                        Text("例如 apple/swift，需要这个 Token 有访问权限。")
                    }
                }
            }
            .navigationTitle("添加仓库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showingAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isAdding ? "校验中…" : "添加") {
                        Task { await add() }
                    }
                    .disabled(newRepoName.isEmpty || isAdding)
                }
            }
        }
    }

    private func add() async {
        isAdding = true
        addError = nil
        defer { isAdding = false }
        do {
            try await environment.repos.add(newRepoName)
            newRepoName = ""
            showingAddSheet = false
        } catch {
            addError = AppError.map(error).localizedDescription
        }
    }
}

private struct RepoManageRow: View {
    @Environment(\.accent) private var accent
    let repo: RepoRecord

    var body: some View {
        HStack(spacing: 10) {
            if repo.isRunning {
                PulsingDot(color: accent.primary, size: 5)
            } else if repo.latestFailed {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(StatusTone.failed, in: .circle)
            } else {
                Circle()
                    .strokeBorder(StatusTone.idle.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 11, height: 11)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(repo.displayName)
                    .font(Type.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Type.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts = [repo.fullName]
        if let filter = repo.workflowFilter, !filter.isEmpty {
            parts.append("仅 \(filter)")
        }
        return parts.joined(separator: " · ")
    }
}
