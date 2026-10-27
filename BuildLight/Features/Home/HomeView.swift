import SwiftUI

/// 首页：一仓库一卡，状态灯 + 进度 + 一键操作。
struct HomeView: View {
    @Environment(BuildStore.self) private var store
    @State private var showingAddRepo = false
    @State private var adding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    summaryLine
                    ForEach(store.snapshots) { snapshot in
                        RepoCard(snapshot: snapshot)
                    }
                    if store.snapshots.isEmpty && !store.isLoading {
                        emptyState
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("构建")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddRepo = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await store.refresh(force: true) }
            .sheet(isPresented: $showingAddRepo) {
                AddRepoSheet(isPresented: $showingAddRepo, adding: $adding)
            }
            .task { store.startPolling() }
        }
    }

    private var summaryLine: some View {
        HStack(spacing: 6) {
            let busy = store.snapshots.filter(\.isBusy).count
            Circle()
                .fill(busy > 0 ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 7, height: 7)
            Text(busy > 0 ? "\(busy) 个在跑" : "全部空闲")
                .font(.footnote.weight(.medium))
            Text("· \(store.repos.count) 个仓库")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text("还没有仓库")
                .font(.headline)
            Text("点右上角 + 添加一个 owner/repo")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

/// 单张仓库卡。
struct RepoCard: View {
    let snapshot: RepoSnapshot
    @Environment(BuildStore.self) private var store

    private var run: WorkflowRun? { snapshot.latestRun }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                statusGlyph
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.repo.name)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let branch = run?.headBranch {
                            Text(branch)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 5))
                                .foregroundStyle(Color.accentColor)
                                .lineLimit(1)
                        }
                        if let number = run?.runNumber {
                            Text("#\(number)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 8)
                trailingMetric
            }

            Divider().opacity(0.5).padding(.vertical, 10)

            HStack {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                actionButton
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
    }

    @ViewBuilder
    private var statusGlyph: some View {
        ZStack {
            switch run?.conclusion {
            case .success?:
                Circle().fill(Color.green).frame(width: 30, height: 30)
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            case .failure?, .timedOut?:
                Circle().fill(Color.red).frame(width: 30, height: 30)
                Image(systemName: "exclamationmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            case .cancelled?:
                Circle().fill(Color.secondary.opacity(0.25)).frame(width: 30, height: 30)
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
            default:
                if run?.isActive == true {
                    Circle().stroke(Color.accentColor.opacity(0.18), lineWidth: 2.6).frame(width: 30, height: 30)
                    Circle().trim(from: 0, to: 0.25)
                        .stroke(Color.accentColor, style: .init(lineWidth: 2.6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 360))
                } else {
                    Circle().fill(Color.secondary.opacity(0.18)).frame(width: 30, height: 30)
                    Image(systemName: "minus").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var trailingMetric: some View {
        if let run, let started = run.runStartedAt {
            let end = run.updatedAt
            Text(workDuration(from: started, to: run.isActive ? Date() : end))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
        } else if run?.isActive == true {
            Text("排队")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var caption: String {
        if let error = snapshot.lastError { return "读取失败 · \(error)" }
        guard let run else { return "还没有构建记录" }
        if run.isActive { return run.status.label }
        return "\(run.conclusion.label) · \(relative(run.updatedAt))"
    }

    @ViewBuilder
    private var actionButton: some View {
        if snapshot.latestSuccess != nil {
            Button("取包") {}
                .font(.system(size: 12.5, weight: .semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(Color.accentColor, in: .capsule)
                .foregroundStyle(.white)
        } else if run?.isActive == true {
            Button("查看") {}
                .font(.system(size: 12.5, weight: .semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1), in: .capsule)
                .foregroundStyle(Color.accentColor)
        }
    }

    private func workDuration(from start: Date, to end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(start)))
        let m = total / 60, s = total % 60
        return m > 0 ? "\(m):\(String(format: "%02d", s))" : "\(s)s"
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
