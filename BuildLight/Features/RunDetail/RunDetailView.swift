import SwiftUI
import SwiftData

struct RunDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var colorScheme
    let run: RunRecord

    @State private var jobs: [WorkflowJob] = []
    @State private var loadError: AppError?
    @State private var isLoading = false

    private var palette: DesignPalette { .resolve(colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let loadError {
                    errorBanner(loadError)
                }
                ForEach(jobs) { job in
                    jobCard(job)
                }
                if !run.artifacts.isEmpty {
                    artifactSection
                }
                actions
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .background(palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: run.isActive) {
            guard run.isActive else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await load()
            }
        }
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            MicroLabel(
                text: "Run #\(run.number) · \(run.workflowName ?? "workflow")",
                color: palette.textTertiary
            )
            Text(run.isActive ? "构建中" : run.conclusion.label)
                .font(.display(33))
                .foregroundStyle(palette.textPrimary)
                .padding(.top, 8)

            HStack(spacing: 7) {
                chip(run.branch ?? "—", highlighted: run.isActive)
                chip(String(run.sha.prefix(7)))
                if let actor = run.actorLogin { chip(actor) }
                chip(elapsedText)
            }
            .padding(.top, 12)

            if let title = run.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .padding(.top, 12)
            }
        }
    }

    private func chip(_ text: String, highlighted: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundStyle(highlighted ? palette.accentStart : palette.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(highlighted ? palette.accentStart.opacity(0.10) : palette.textPrimary.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(highlighted ? palette.accentStart.opacity(0.3) : palette.hairline, lineWidth: 0.5)
                    }
            }
    }

    // MARK: 任务卡

    private func jobCard(_ job: WorkflowJob) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(job.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text(jobTime(job))
                    .font(.metric(11))
                    .foregroundStyle(palette.textTertiary)
            }
            .padding(.bottom, 10)

            Divider().overlay(palette.hairline)

            ForEach(job.steps) { step in
                stepRow(step)
            }
        }
        .padding(16)
        .background(palette.surface, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(palette.hairline, lineWidth: 0.5)
        }
    }

    private func stepRow(_ step: WorkflowStep) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: iconName(for: step))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(iconColor(for: step))
                .frame(width: 12)
            Text(step.name)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(step.status == .inProgress ? palette.textPrimary : palette.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(stepTime(step))
                .font(.metric(10.5))
                .foregroundStyle(palette.textTertiary)
        }
        .padding(.vertical, 8)
    }

    private func iconName(for step: WorkflowStep) -> String {
        switch step.status {
        case .inProgress: return "arrowtriangle.right.fill"
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
        if step.status == .inProgress { return palette.accentStart }
        switch step.conclusion {
        case .success: return palette.textTertiary
        case .failure, .timedOut: return palette.failure
        default: return palette.textTertiary
        }
    }

    // MARK: 产物

    private var artifactSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MicroLabel(text: "Artifacts", color: palette.textTertiary)
            ForEach(run.artifacts.sorted { $0.sizeBytes > $1.sizeBytes }) { artifact in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(artifact.name)
                            .font(.system(size: 12.5))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                        Text(artifactSubtitle(artifact))
                            .font(.system(size: 10.5))
                            .foregroundStyle(palette.textSecondary)
                    }
                    Spacer(minLength: 8)
                    if artifact.expired {
                        Text("已过期")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.textTertiary)
                    } else {
                        PackageButton(artifact: artifact, run: run)
                    }
                }
                .padding(14)
                .background(palette.surface, in: .rect(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(palette.hairline, lineWidth: 0.5)
                }
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

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                perform {
                    guard let client else { return }
                    try await client.rerun(owner: owner, repo: name, runID: run.id)
                }
            } label: {
                actionLabel("重跑")
            }
            if run.isActive {
                Button {
                    perform {
                    guard let client else { return }
                    try await client.cancel(owner: owner, repo: name, runID: run.id)
                }
                } label: {
                    actionLabel("取消")
                }
            }
            Link(destination: run.htmlURL) {
                actionLabel("在浏览器打开")
            }
        }
        .padding(.top, 4)
    }

    private func actionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(palette.textPrimary.opacity(0.04), in: .capsule)
            .overlay { Capsule().strokeBorder(palette.hairline, lineWidth: 0.5) }
    }

    // MARK: 数据

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

    // MARK: 格式化

    private var elapsedText: String {
        guard let start = run.startedAt else { return "排队" }
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
        let minutes = total / 60
        let seconds = total % 60
        return minutes > 0 ? "\(minutes)m \(String(format: "%02d", seconds))s" : "\(seconds)s"
    }

    private func errorBanner(_ error: AppError) -> some View {
        Text(error.localizedDescription)
            .font(.system(size: 11.5))
            .foregroundStyle(palette.failure)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(palette.failure.opacity(0.08), in: .rect(cornerRadius: 12))
    }
}
