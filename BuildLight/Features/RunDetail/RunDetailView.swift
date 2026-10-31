import SwiftData
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

    /// 产物用独立 `@Query` 读，不走 `run.artifacts` 关系。
    ///
    /// 两个原因：
    /// 1. 关系数组是 SwiftData 的懒加载集合，页面持有的是普通 `let run`，
    ///    新插入的产物不保证触发重绘——表现为「有时候不显示，退出去再进来又有」。
    /// 2. `@Query` 由存储驱动，插入即成真，下载中也不会突然消失。
    @Query private var artifacts: [ArtifactRecord]

    @State private var jobs: [WorkflowJob] = []
    @State private var loadError: AppError?
    @State private var isLoading = false
    /// 自动定位只做一次。轮询每次都会替换 jobs，
    /// 不加这个标记的话，用户往上翻会被每 3 秒拽回失败步骤。
    @State private var didAutoScroll = false
    @State private var didLoadArtifacts = false

    init(run: RunRecord) {
        self.run = run
        let runID = run.id
        _artifacts = Query(
            filter: #Predicate<ArtifactRecord> { $0.runID == runID },
            sort: [SortDescriptor(\ArtifactRecord.sizeBytes, order: .reverse)]
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: jobs) { _, newValue in
                    guard !didAutoScroll, !newValue.isEmpty else { return }
                    didAutoScroll = true
                    scrollToFailure(proxy)
                }
        }
        .scrollIndicators(.hidden)
        .background(PaperBackground())
        .navigationTitle("#\(run.number)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
            await loadArtifactsIfNeeded()
        }
        .task(id: run.isActive) { await pollWhileRunning() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                metaBlock

                if let loadError {
                    Text(loadError.localizedDescription)
                        .scaledFont(size: 12)
                        .foregroundStyle(StatusTone.failed)
                        .padding(.horizontal, DS.pad)
                        .padding(.top, 10)
                }

                ForEach(jobs) { job in
                    SectionLabel(job.name)
                        .id("job-\(job.id)")
                    ForEach(job.steps) { step in
                        StepRow(step: step)
                            // step.number 只在 job 内唯一，跨 job 会撞号，
                            // 锚点必须带上 job.id 才不会滚错位置。
                            .id("step-\(job.id)-\(step.number)")
                    }
                    Hairline(leading: DS.pad)
                }

                if !sortedArtifacts.isEmpty {
                    SectionLabel("安装包", trailing: "\(sortedArtifacts.count)")
                    ForEach(sortedArtifacts) { artifact in
                        ArtifactRow(artifact: artifact)
                    }
                } else if !didLoadArtifacts {
                    // 「还在拉」和「确实没有」必须分开显示。
                    // 之前两者都渲染成空白，用户根本不知道是没有包还是没加载出来。
                    SectionLabel("安装包")
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("正在获取产物…")
                            .font(Type.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, DS.pad)
                    .padding(.vertical, 8)
                } else {
                    SectionLabel("安装包")
                    Text("这次构建没有产出安装包")
                        .font(Type.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, DS.pad)
                        .padding(.vertical, 8)
                }

                actions
                    .padding(.top, 28)
            }
            .padding(.bottom, 40)
        }
        .refreshable {
            await load()
            didLoadArtifacts = false
            await loadArtifactsIfNeeded()
        }
    }

    /// 失败运行时自动滚到第一个失败步骤——
    /// 用户点进一条失败的记录，想看的就是「哪一步挂了」，
    /// 不应该让他从头往下翻。
    private func scrollToFailure(_ proxy: ScrollViewProxy) {
        // 直接找 (job, step) 组合。只按 step.number 找的话，
        // 两个 job 都有「第 3 步失败」时会滚到错误的位置。
        let anchor: String? = jobs.lazy.compactMap { job -> String? in
            guard let step = job.steps.first(where: \.isFailed) else { return nil }
            return "step-\(job.id)-\(step.number)"
        }.first

        guard let anchor else { return }
        withAnimation(Motion.settle) {
            proxy.scrollTo(anchor, anchor: .center)
        }
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(tone).frame(width: 6, height: 6)
                Text(statusText)
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(tone)
                Spacer()
                Text(run.event)
                    .scaledFont(size: 11)
                    .foregroundStyle(.tertiary)
            }

            Text(run.title ?? run.workflowName ?? "#\(run.number)")
                .scaledFont(size: 21, weight: .semibold)
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
                .scaledFont(size: 34, weight: .semibold)
                .foregroundStyle(run.isActive ? accent.primary : .primary)
            Text(run.isActive ? (run.startedAt == nil ? "排队中" : "进行中") : "总耗时")
                .scaledFont(size: 11)
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
                .scaledFont(size: 12)
                .foregroundStyle(.tertiary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .scaledFont(size: 13)
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

            HStack(spacing: 10) {
                if let packageURL = copyablePackageURL {
                    CopyLinkButton(url: packageURL)
                }

                Link(destination: run.htmlURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                            .font(.system(size: 13, weight: .semibold))
                        Text("浏览器打开")
                            .scaledFont(size: 14)
                    }
                    .foregroundStyle(accent.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(accent.primary.opacity(0.10), in: .rect(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, DS.pad)
    }

    // MARK: 计算

    /// 底部「复制下载直链」用哪个地址。
    ///
    /// 优先复制安装包的网页直链——那才是能直接粘进浏览器下载的东西；
    /// 没有产物时退回运行页地址，至少能分享这次构建。
    private var copyablePackageURL: URL? {
        if let artifact = sortedArtifacts.first(where: { !$0.expired }),
           let webURL = artifact.webDownloadURL {
            return webURL
        }
        return run.htmlURL
    }

    private var sortedArtifacts: [ArtifactRecord] {
        artifacts.filter { PackageFilter.looksLikeIPA($0.name) }
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

    /// 老运行的产物没在首页预拉过，进详情页时补一次。
    ///
    /// 只有**成功**才置位：之前是先置位再请求，
    /// 一次断网/取消就永久放弃，这个页面实例再也不会补拉。
    private func loadArtifactsIfNeeded() async {
        guard !didLoadArtifacts else { return }
        if await environment.monitor.ensureArtifacts(for: run) {
            didLoadArtifacts = true
        }
    }

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
