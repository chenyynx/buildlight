import SwiftUI
import SwiftData

struct RunDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    let run: RunRecord

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

            Section {
                LabeledContent("状态") {
                    Label(statusText, systemImage: statusSymbol)
                        .foregroundStyle(statusColor)
                }
                LabeledContent("分支", value: run.branch ?? "—")
                LabeledContent("提交", value: String(run.sha.prefix(7)))
                if let actor = run.actorLogin {
                    LabeledContent("触发人", value: actor)
                }
                if let started = run.startedAt {
                    TimelineView(.periodic(from: started, by: 1)) { _ in
                        LabeledContent("耗时", value: elapsedText)
                    }
                } else {
                    LabeledContent("耗时", value: "排队中")
                }
            }

            ForEach(jobs) { job in
                Section {
                    ForEach(job.steps) { step in
                        StepRow(step: step)
                    }
                } header: {
                    HStack {
                        Text(job.name)
                        Spacer()
                        Text(jobDuration(job))
                            .monospacedDigit()
                    }
                }
            }

            if !run.artifacts.isEmpty {
                Section("构建产物") {
                    ForEach(sortedArtifacts) { artifact in
                        ArtifactRow(artifact: artifact)
                    }
                }
            }

            Section {
                Button("重新运行", systemImage: "arrow.clockwise") {
                    rerun()
                }
                if run.isActive {
                    Button("取消运行", systemImage: "xmark", role: .destructive) {
                        cancel()
                    }
                }
                Link(destination: run.htmlURL) {
                    Label("在浏览器中打开", systemImage: "safari")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("#\(run.number)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: run.isActive) { await pollWhileRunning() }
        .refreshable { await load() }
    }

    // MARK: 计算

    private var sortedArtifacts: [ArtifactRecord] {
        run.artifacts.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private var statusText: String {
        run.isActive ? run.status.label : run.conclusion.label
    }

    private var statusSymbol: String {
        if run.isActive { return "arrow.triangle.2.circlepath" }
        switch run.conclusion {
        case .success: return "checkmark.circle"
        case .failure, .timedOut: return "xmark.circle"
        default: return "minus.circle"
        }
    }

    private var statusColor: Color {
        if run.isActive { return StatusTone.running }
        switch run.conclusion {
        case .success: return StatusTone.idle
        case .failure, .timedOut: return StatusTone.failed
        default: return .secondary
        }
    }

    private var elapsedText: String {
        guard let start = run.startedAt else { return "—" }
        let end = run.isActive ? Date() : run.updatedAt
        let total = max(0, Int(end.timeIntervalSince(start)))
        return "\(total / 60) 分 \(total % 60) 秒"
    }

    private func jobDuration(_ job: WorkflowJob) -> String {
        guard let start = job.startedAt else { return "—" }
        let total = max(0, Int((job.completedAt ?? Date()).timeIntervalSince(start)))
        return "\(total / 60)m \(total % 60)s"
    }

    private var owner: String {
        run.repo?.owner ?? run.repoFullName.split(separator: "/").first.map(String.init) ?? ""
    }

    private var name: String {
        run.repo?.name ?? run.repoFullName.split(separator: "/").last.map(String.init) ?? ""
    }

    // MARK: 行为

    private func load() async {
        guard let client = environment.session.client, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            jobs = try await client.jobs(owner: owner, repo: name, runID: run.id)
            loadError = nil
        } catch {
            loadError = AppError.map(error)
        }
    }

    private func pollWhileRunning() async {
        guard run.isActive else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            await load()
        }
    }

    private func rerun() {
        guard let client = environment.session.client else { return }
        Task {
            do {
                try await client.rerun(owner: owner, repo: name, runID: run.id)
                await load()
            } catch {
                loadError = AppError.map(error)
            }
        }
    }

    private func cancel() {
        guard let client = environment.session.client else { return }
        Task {
            do {
                try await client.cancel(owner: owner, repo: name, runID: run.id)
                await load()
            } catch {
                loadError = AppError.map(error)
            }
        }
    }
}
