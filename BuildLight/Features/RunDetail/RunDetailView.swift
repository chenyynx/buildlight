import SwiftUI

/// 单次运行的详情页：耗时大数字 + 步骤流 + 产物 + 操作。
///
/// 「签名细节」：页面顶部的耗时是一个 34pt 的等宽数字，
/// 跑动时它每秒走一次。它是这个页面唯一会动的东西——
/// 构建进行中，用户需要的是「还在动」这一个确认。
struct RunDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accent) private var accent
    let run: RunRecord

    @State private var jobs: [WorkflowJob] = []
    @State private var loadError: AppError?
    @State private var isLoading = false

    var body: some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: jobs) { _, _ in
                    scrollToFailure(proxy)
                }
        }
        .scrollIndicators(.hidden)
        .background(PaperBackground())
        .navigationTitle("#\(run.number)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: run.isActive) { await pollWhileRunning() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                metaBlock

                if let loadError {
                    Text(loadError.localizedDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(StatusTone.failed)
                        .padding(.horizontal, DS.pad)
                        .padding(.top, 10)
                }

                ForEach(jobs) { job in
                    SectionLabel(job.name)
                        .id("job-\(job.id)")
                    ForEach(job.steps) { step in
                        StepRow(step: step)
                            .id("step-\(step.id)")
                    }
                    Hairline(leading: DS.pad)
                }

                if !sortedArtifacts.isEmpty {
                    SectionLabel("安装包")
                    ForEach(sortedArtifacts) { artifact in
                        ArtifactRow(artifact: artifact)
                    }
                }

                actions
                    .padding(.top, 28)
            }
            .padding(.bottom, 40)
        }
        .refreshable { await load() }
    }

    /// 失败运行时自动滚到第一个失败步骤——
    /// 用户点进一条失败的记录，想看的就是「哪一步挂了」，
    /// 不应该让他从头往下翻。
    private func scrollToFailure(_ proxy: ScrollViewProxy) {
        guard let failed = jobs
            .flatMap(\.steps)
            .first(where: { $0.conclusion == .failure || $0.conclusion == .timedOut })
        else { return }
        withAnimation(Motion.settle) {
            proxy.scrollTo("step-\(failed.id)", anchor: .center)
        }
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(tone).frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tone)
                Spacer()
                Text(run.event)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Text(run.title ?? run.workflowName ?? "#\(run.number)")
                .font(.system(size: 21, weight: .semibold))
                .tracking(-0.3)
                .lineLimit(3)
                .padding(.top, 2)

            if run.isActive, let start = run.startedAt {
                durationLine {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                }
            } else if run.isActive {
                // 排队中：还没有 startedAt，用创建时间起算，但只是静态显示
                durationLine {
                    Text(RepoDurationText.clock(from: run.createdAt, to: .now))
                        .monospacedDigit()
                }
            } else {
                durationLine {
                    Text(RepoDurationText.clock(from: run.startedAt ?? run.createdAt, to: run.updatedAt))
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, DS.pad)
        .padding(.top, 8)
    }

    private func durationLine<Value: View>(@ViewBuilder value: () -> Value) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            value()
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(run.isActive ? accent.primary : .primary)
            Text(run.isActive ? (run.startedAt == nil ? "排队中" : "进行中") : "总耗时")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }

    private var metaBlock: some View {
        VStack(spacing: 0) {
            metaRow("分支", run.branch ?? "—")
            metaRow("提交", String(run.sha.prefix(7)))
            if let actor = run.actorLogin {
                metaRow("触发人", actor)
            }
            metaRow("开始", run.startedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "排队中")
        }
        .padding(.top, 18)
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.pad)
        .padding(.vertical, 5)
    }

    // MARK: 操作

    private var actions: some View {
        VStack(spacing: 8) {
            PrimaryButton(title: "重新运行", systemImage: "arrow.clockwise") {
                rerun()
            }

            if run.isActive {
                PrimaryButton(title: "取消运行", systemImage: "xmark", tint: StatusTone.failed) {
                    cancel()
                }
            }

            Link(destination: run.htmlURL) {
                Text("在浏览器中打开")
                    .font(.system(size: 14))
                    .foregroundStyle(accent.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
        }
        .padding(.horizontal, DS.pad)
    }

    // MARK: 计算

    private var sortedArtifacts: [ArtifactRecord] {
        run.artifacts
            .filter { PackageFilter.looksLikeIPA($0.name) }
            .sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private var statusText: String {
        run.isActive ? run.status.label : run.conclusion.label
    }

    private var tone: Color {
        if run.isActive { return accent.primary }
        switch run.conclusion {
        case .failure, .timedOut: return StatusTone.failed
        default: return StatusTone.idle
        }
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
