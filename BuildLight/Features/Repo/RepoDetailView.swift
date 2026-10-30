import SwiftUI
import SwiftData

/// 仓库详情页：仓库信息 + 最新产物 + 构建记录。
///
/// 顶部用玻璃面板承载「这个仓库现在的状态」，
/// 下面是扁平的构建记录列表——记录是流水，列表比卡片更合适。
struct RepoDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accent) private var accent
    @Query private var runs: [RunRecord]
    @Environment(\.openURL) private var openURL

    /// 待确认的远端操作。取消/重跑都会真的影响 CI，不能一滑就执行。
    @State private var pendingAction: PendingAction?

    private let repo: RepoRecord

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
            header
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if let target = latestPackage {
                packageBlock(target)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(filteredRuns) { run in
                    ZStack(alignment: .bottom) {
                        NavigationLink(value: RunRoute(runID: run.id)) {
                            RunRowView(run: run)
                        }
                        .buttonStyle(PressableStyle())

                        Hairline(leading: DS.pad + 18)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if run.isActive {
                            Button("取消", systemImage: "xmark", role: .destructive) {
                                pendingAction = .cancel(run)
                            }
                        } else {
                            Button("重跑", systemImage: "arrow.clockwise") {
                                pendingAction = .rerun(run)
                            }
                            .tint(accent.primary)
                        }
                    }
                }
            } header: {
                SectionLabel("构建记录")
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .background(PaperBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(repo.displayName)
        .navigationDestination(for: RunRoute.self) { route in
            if let run = filteredRuns.first(where: { $0.id == route.runID }) {
                RunDetailView(run: run)
            }
        }
        .refreshable { await environment.monitor.refreshNow() }
        .confirmationDialog(
            pendingAction?.title ?? "",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = pendingAction {
                Button(action.confirmTitle, role: action.isDestructive ? .destructive : nil) {
                    Task { await action.perform(environment) }
                    pendingAction = nil
                }
                Button("取消", role: .cancel) { pendingAction = nil }
            }
        } message: {
            if let action = pendingAction {
                Text(action.message)
            }
        }
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

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScreenHeader(title: repo.displayName, subtitle: headerSubtitle)

            GlassSurface(level: .panel, cornerRadius: Metrics.radiusL) {
                HStack(spacing: 0) {
                    MetricCell(value: "\(filteredRuns.count)", label: "次构建")
                    VerticalRule()
                    MetricCell(
                        value: "\(successCount)",
                        label: "成功",
                        tint: successCount > 0 ? nil : StatusTone.idle
                    )
                    VerticalRule()
                    MetricCell(
                        value: "\(failureCount)",
                        label: "失败",
                        tint: failureCount > 0 ? StatusTone.failed : nil
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .padding(.horizontal, DS.pad)
            .padding(.bottom, 6)
        }
    }

    private var headerSubtitle: String {
        var parts: [String] = []
        if let workflow = repo.workflowFilter, !workflow.isEmpty { parts.append(workflow) }
        if let branch = repo.latestBranch, !branch.isEmpty { parts.append(branch) }
        if let at = repo.latestRunAt { parts.append("最近 " + RelativeTime.text(for: at)) }
        return parts.joined(separator: " · ")
    }

    private var successCount: Int {
        filteredRuns.count { $0.conclusion == .success }
    }

    private var failureCount: Int {
        filteredRuns.count { $0.conclusion == .failure || $0.conclusion == .timedOut }
    }

    // MARK: 最新产物

    private var latestPackage: PackageTarget? {
        guard let id = repo.packageID,
              let name = repo.packageName,
              let url = repo.packageURL
        else { return nil }
        return PackageTarget(
            id: id,
            name: name,
            archiveURL: url,
            repoName: repo.name,
            runNumber: repo.latestNumber,
            branch: repo.latestBranch ?? "",
            workflowName: repo.latestWorkflowName ?? ""
        )
    }

    private func packageBlock(_ target: PackageTarget) -> some View {
        GlassSurface(level: .card, cornerRadius: Metrics.radiusL) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(accent.primary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(target.name)
                            .scaledFont(size: 15, weight: .semibold)
                            .lineLimit(1)

                        // 一眼看出这个包是哪次构建、哪条分支出来的。
                        // 之前只有文件名和大小，取错包还得回列表比对。
                        Text(buildLine)
                            .scaledFont(size: 12)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)

                        Text(packageDetail(target))
                            .scaledFont(size: 12)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                packageAction(target)
            }
            .padding(16)
        }
        .padding(.horizontal, DS.pad)
        .padding(.top, 14)
    }

    /// 「#63 · main · e5a28c4」。
    private var buildLine: String {
        var parts: [String] = []
        if repo.latestNumber > 0 { parts.append("#\(repo.latestNumber)") }
        if let branch = repo.latestBranch, !branch.isEmpty { parts.append(branch) }
        if let run = filteredRuns.first(where: { $0.id == repo.latestRunID }) {
            parts.append(String(run.sha.prefix(7)))
        }
        return parts.isEmpty ? "最新构建" : parts.joined(separator: " · ")
    }

    private func packageDetail(_ target: PackageTarget) -> String {
        let size = repo.packageSize > 0
            ? ByteCountFormatter.string(fromByteCount: Int64(repo.packageSize), countStyle: .file)
            : "—"

        switch environment.packages.state(for: target.id) {
        case .downloading(let progress):
            var parts = ["下载中 \(Int(progress * 100))%"]
            if let speed = environment.packages.speed(for: target.id), let text = ByteRate.text(speed) {
                parts.append(text)
            }
            parts.append(size)
            return parts.joined(separator: " · ")
        case .paused(let progress):
            return "已下载 \(Int(progress * 100))% · 点下面继续 · \(size)"
        case .unzipping:
            return "正在解压 · \(size)"
        case .ready:
            return "已就绪 · \(size)"
        default:
            return size
        }
    }

    @ViewBuilder
    private func packageAction(_ target: PackageTarget) -> some View {
        switch environment.packages.state(for: target.id) {
        case .idle:
            PrimaryButton(title: "下载并导入", systemImage: "arrow.down") {
                environment.packages.start(target)
            }
        case .paused:
            PrimaryButton(title: "继续下载", systemImage: "arrow.down") {
                environment.packages.start(target)
            }
        case .downloading(let progress):
            DownloadProgressBar(progress: progress)
        case .unzipping:
            DownloadProgressBar(progress: 1)
                .opacity(0.45)
        case .ready(let url):
            ShareLink(item: url) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .scaledFont(size: 13, weight: .semibold)
                    Text("导入到全能签")
                        .scaledFont(size: 15, weight: .semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(accent.primary, in: .rect(cornerRadius: 13))
            }
            .buttonStyle(PressableStyle())
        case .failed(let error):
            VStack(alignment: .leading, spacing: 8) {
                Text(error.localizedDescription)
                    .scaledFont(size: 12)
                    .foregroundStyle(StatusTone.failed)
                PrimaryButton(title: "重试", systemImage: "arrow.clockwise", tint: StatusTone.failed) {
                    environment.packages.start(target)
                }
            }
        }
    }

    // MARK: 数据

    private var filteredRuns: [RunRecord] {
        guard let filter = repo.workflowFilter, !filter.isEmpty else { return runs }
        return runs.filter { $0.workflowName == filter }
    }
}
