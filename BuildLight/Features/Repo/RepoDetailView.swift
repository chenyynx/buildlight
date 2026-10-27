import SwiftUI
import SwiftData

struct RepoDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Query private var runs: [RunRecord]

    private let repo: RepoRecord
    private var palette: Palette { .resolve(colorScheme) }

    init(repo: RepoRecord) {
        self.repo = repo
        let fullName = repo.fullName
        _runs = Query(
            filter: #Predicate<RunRecord> { $0.repoFullName == fullName },
            sort: [SortDescriptor(\RunRecord.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        List {
            ForEach(filteredRuns) { run in
                NavigationLink {
                    RunDetailView(run: run)
                } label: {
                    RunRow(run: run, palette: palette)
                }
                .listRowBackground(palette.surface)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if run.isActive {
                        Button(role: .destructive) {
                            perform {
                                guard let client = environment.session.client else { return }
                                try await client.cancel(owner: repo.owner, repo: repo.name, runID: run.id)
                            }
                        } label: {
                            Label("取消", systemImage: "xmark")
                        }
                    } else {
                        Button {
                            perform {
                                guard let client = environment.session.client else { return }
                                try await client.rerun(owner: repo.owner, repo: repo.name, runID: run.id)
                            }
                        } label: {
                            Label("重跑", systemImage: "arrow.clockwise")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .editorialBackground(palette)
        .navigationTitle(repo.displayName)
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await environment.monitor.refreshNow() }
        .overlay {
            if filteredRuns.isEmpty {
                ContentUnavailableView(
                    "还没有运行记录",
                    systemImage: "hammer",
                    description: Text("下拉可以刷新")
                )
            }
        }
    }

    private var filteredRuns: [RunRecord] {
        guard let filter = repo.workflowFilter, !filter.isEmpty else { return runs }
        return runs.filter { $0.workflowName == filter }
    }

    private func perform(_ work: @escaping () async throws -> Void) {
        Task { try? await work() }
    }
}

struct RunRow: View {
    let run: RunRecord
    let palette: Palette

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 3) {
                Text(run.title?.isEmpty == false ? run.title! : (run.workflowName ?? "运行"))
                    .font(.system(size: 14.5))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Text("#\(run.number) · \(run.branch ?? "—")")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(run.isActive ? "运行中" : run.conclusion.label)
                    .font(.system(size: 11))
                    .foregroundStyle(statusColor)
                Text(relative(run.createdAt))
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.textTertiary)
            }
        }
        .padding(.vertical, 3)
    }

    private var statusColor: Color {
        if run.isActive { return palette.accentStart }
        switch run.conclusion {
        case .success: return palette.textSecondary
        case .failure, .timedOut: return palette.failure
        default: return palette.textTertiary
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
