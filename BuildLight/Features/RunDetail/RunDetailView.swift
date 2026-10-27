import SwiftUI
import SwiftData

struct RunDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var colorScheme
    let run: RunRecord

    private var palette: Palette { .resolve(colorScheme) }

    @State private var jobs: [WorkflowJob] = []
    @State private var loadError: AppError?
    @State private var isLoading = false

    var body: some View {
        List {
            if let loadError {
                Section {
                    Label(loadError.localizedDescription, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            overviewSection

            ForEach(jobs) { job in
                Section {
                    ForEach(job.steps) { step in
                        stepRow(step)
                    }
                } header: {
                    HStack {
                        Text(job.name)
                        Spacer()
                        Text(jobTime(job))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !run.artifacts.isEmpty {
                artifactsSection
            }

            actionsSection
        }
        .listStyle(.insetGrouped)
        .editorialBackground(palette)
        .navigationTitle("#\(run.number)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: run.isActive) {
            guard run.isActive else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await load()
            }
        }
        .refreshable { await load() }
    }

    // MARK: 概览

    private var overviewSection: some View {
        Section {
            LabeledContent("状态") {
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(run.isActive ? run.status.label : run.conclusion.label)
                }
            }
            if let branch = run.branch {
                LabeledContent("分支", value: branch)
            }
            LabeledContent("提交", value: String(run.sha.prefix(7)))
            if let actor = run.actorLogin {
                LabeledContent("触发人", value: actor)
            }
            LabeledContent("耗时", value: elapsedText)
            if let title = run.title, !title.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                    if let workflow = run.workflowName {
                        Text(workflow)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: 步骤

    private func stepRow(_ step: WorkflowStep) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconName(for: step))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(iconColor(for: step))
                .frame(width: 14)
            Text(step.name)
                .font(.footnote)
                .foregroundStyle(step.status == .inProgress ? palette.textPrimary : palette.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(stepTime(step))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    private func iconName(for step: WorkflowStep) -> String {
        switch step.status {
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed:
            switch step.conclusion {
            case .success: return "checkmark"
            case .failure, .timedOut: return "xmark"
            case .skipped: return "minus"
            default: return "minus"
            }
        default: return "circle"
        }
    }

    private func iconColor(for step: WorkflowStep) -> Color {
        if step.status == .inProgress { return .blue }
        switch step.conclusion {
        case .success: return .secondary
        case .failure, .timedOut: return .red
        default: return .secondary
        }
    }

    // MARK: 产物

    private var artifactsSection: some View {
        Section("构建产物") {
            ForEach(run.artifacts.sorted { $0.sizeBytes > $1.sizeBytes }) { artifact in
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(artifact.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(artifactSubtitle(artifact))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if artifact.expired {
                        Text("已过期")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        PackageButton(artifact: artifact, run: run)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func artifactSubtitle(_ artifact: ArtifactRecord) -> String {
        var parts = [artifact.sizeText]
        if let expires = artifact.expiresAt {
            let days = Calendar.current.dateComponents([.day], from: .now, to: expires).day ?? 0
            parts.append(days > 0 ? "剩 \(days) 天" : "即将过期")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: 操作

    private var actionsSection: some View {
        Section {
            Button {
                perform {
                    guard let client = client else { return }
                    try await client.rerun(owner: owner, repo: name, runID: run.id)
                }
            } label: {
                Label("重新运行", systemImage: "arrow.clockwise")
            }

            if run.isActive {
                Button(role: .destructive) {
                    perform {
                        guard let client = client else { return }
                        try await client.cancel(owner: owner, repo: name, runID: run.id)
                    }
                } label: {
                    Label("取消运行", systemImage: "xmark")
                }
            }

            Link(destination: run.htmlURL) {
                Label("在浏览器中打开", systemImage: "safari")
            }
        }
    }

    // MARK: 数据

    private var statusColor: Color {
        if run.isActive { return .blue }
        switch run.conclusion {
        case .success: return .green
        case .failure, .timedOut: return .red
        default: return .secondary
        }
    }

    private var owner: String {
        run.repo?.owner ?? run.repoFullName.split(separator: "/").first.map(String.init) ?? ""
    }

    private var name: String {
        run.repo?.name ?? run.repoFullName.split(separator: "/").last.map(String.init) ?? ""
    }

    private var client: GitHubClient? { environment.session.client }

    private func load() async {
        guard let client, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            jobs = try await client.jobs(owner: owner, repo: name, runID: run.id)
            loadError = nil
        } catch {
            loadError = AppError.map(error)
        }
    }

    private func perform(_ work: @escaping () async throws -> Void) {
        Task {
            do {
                try await work()
                await load()
            } catch {
                loadError = AppError.map(error)
            }
        }
    }

    private var elapsedText: String {
        guard let start = run.startedAt else { return "排队中" }
        let end = run.isActive ? Date() : run.updatedAt
        return shortDuration(from: start, to: end)
    }

    private func jobTime(_ job: WorkflowJob) -> String {
        guard let start = job.startedAt else { return "—" }
        return shortDuration(from: start, to: job.completedAt ?? Date())
    }

    private func stepTime(_ step: WorkflowStep) -> String {
        guard let start = step.startedAt else { return "—" }
        return shortDuration(from: start, to: step.completedAt ?? Date())
    }

    private func shortDuration(from start: Date, to end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(start)))
        return "\(total / 60)m \(String(format: "%02d", total % 60))s"
    }
}
