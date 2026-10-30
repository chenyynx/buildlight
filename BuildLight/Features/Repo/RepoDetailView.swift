import SwiftUI
import SwiftData

struct RepoDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query private var runs: [RunRecord]

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
            if let target = latestPackage {
                Section {
                    latestPackageRow(target)
                } header: {
                    Text("最新产物")
                } footer: {
                    Text(packageFooter)
                }
            }

            ForEach(filteredRuns) { run in
                NavigationLink(value: RunRoute(runID: run.id)) {
                    RunRow(run: run)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if run.isActive {
                        Button("取消", systemImage: "xmark", role: .destructive) {
                            cancel(run)
                        }
                    } else {
                        Button("重跑", systemImage: "arrow.clockwise") {
                            rerun(run)
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(repo.displayName)
        .navigationDestination(for: RunRoute.self) { route in
            if let run = filteredRuns.first(where: { $0.id == route.runID }) {
                RunDetailView(run: run)
            }
        }
        .refreshable {
            await environment.monitor.refreshNow()
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

    private var latestPackage: PackageTarget? {
        guard let id = repo.packageID,
              let name = repo.packageName,
              let url = repo.packageURL
        else { return nil }
        return PackageTarget(id: id, name: name, archiveURL: url)
    }

    /// 进详情第一屏就是包，不用再往下翻。
    private func latestPackageRow(_ target: PackageTarget) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Accent.primary)
                .frame(width: 36, height: 36)
                .background(Accent.soft, in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(target.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                switch environment.packages.state(for: target.id) {
                case .paused(let progress):
                    Text("已下载 \(Int(progress * 100))% · \(packageSizeText) · 点右侧继续")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    DownloadProgressBar(progress: progress, height: 3)
                        .opacity(0.55)
                        .padding(.top, 2)
                case .downloading(let progress):
                    Text(downloadLine(progress: progress, artifactID: target.id))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Accent.primary)
                    DownloadProgressBar(progress: progress, height: 3)
                        .padding(.top, 2)
                case .unzipping:
                    Text("正在解压 · \(packageSizeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                default:
                    Text(packageSizeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)
            PackageButton(target: target)
        }
        .padding(.vertical, 2)
    }

    private func downloadLine(progress: Double, artifactID: Int) -> String {
        var parts = ["下载中 \(Int(progress * 100))%"]
        if let speed = environment.packages.speed(for: artifactID), let text = ByteRate.text(speed) {
            parts.append(text)
        }
        parts.append(packageSizeText)
        return parts.joined(separator: " · ")
    }

    private var packageSizeText: String {
        repo.packageSize > 0
            ? ByteCountFormatter.string(fromByteCount: Int64(repo.packageSize), countStyle: .file)
            : "点右侧下载"
    }

    private var packageFooter: String {
        var parts: [String] = []
        if let branch = repo.latestBranch, !branch.isEmpty { parts.append(branch) }
        if repo.latestNumber > 0 { parts.append("#\(repo.latestNumber)") }
        parts.append("构建完成后自动更新")
        return parts.joined(separator: " · ")
    }

    private var filteredRuns: [RunRecord] {
        guard let filter = repo.workflowFilter, !filter.isEmpty else { return runs }
        return runs.filter { $0.workflowName == filter }
    }

    private func rerun(_ run: RunRecord) {
        guard let client = environment.session.client else { return }
        Task { try? await client.rerun(owner: repo.owner, repo: repo.name, runID: run.id) }
    }

    private func cancel(_ run: RunRecord) {
        guard let client = environment.session.client else { return }
        Task { try? await client.cancel(owner: repo.owner, repo: repo.name, runID: run.id) }
    }
}
