import SwiftUI
import SwiftData

struct RepoCard: View {
    @Environment(AppEnvironment.self) private var environment
    let repo: RepoRecord
    let palette: DesignPalette

    private var runs: [RunRecord] {
        let all = repo.runs.sorted { $0.createdAt > $1.createdAt }
        guard let filter = repo.workflowFilter, !filter.isEmpty else { return all }
        return all.filter { $0.workflowName == filter }
    }

    private var latest: RunRecord? { runs.first }
    private var active: [RunRecord] { runs.filter(\.isActive) }
    private var artifact: ArtifactRecord? {
        (latest?.artifacts ?? [])
            .filter { !$0.expired }
            .max { score($0.name) < score($1.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(repo.displayName)
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    MicroLabel(
                        text: [latest?.workflowName, latest?.branch].compactMap { $0 }.joined(separator: " · "),
                        color: palette.textSecondary
                    )
                    .lineLimit(1)
                }
                Spacer(minLength: 8)
                statusPill
            }

            HStack(alignment: .firstTextBaseline) {
                Text(durationText)
                    .font(.display(27))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text(subMetric)
                    .font(.system(size: 10.5, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(palette.textTertiary)
            }
            .padding(.top, 13)

            progressBar
                .padding(.top, 12)

            HStack(alignment: .center) {
                Text(caption)
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let artifact, let run = latest {
                    PackageButton(artifact: artifact, run: run)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                }
            }
            .padding(.top, 12)

            if active.count > 1 {
                subRuns
                    .padding(.top, 10)
            }
        }
        .padding(16)
        .background(palette.surface, in: .rect(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(palette.hairline, lineWidth: 0.5)
        }
    }

    // MARK: 子视图

    private var statusPill: some View {
        Text(pillText)
            .font(.system(size: 9, weight: .medium))
            .tracking(1.3)
            .foregroundStyle(pillColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay {
                Capsule().strokeBorder(pillColor.opacity(0.45), lineWidth: 0.5)
            }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.textPrimary.opacity(0.09))
                Capsule()
                    .fill(barFill)
                    .frame(width: max(0, proxy.size.width * ratio))
            }
        }
        .frame(height: 3)
    }

    private var subRuns: some View {
        VStack(spacing: 6) {
            Divider().overlay(palette.hairline)
            ForEach(active.dropFirst().prefix(2)) { run in
                HStack(spacing: 8) {
                    Circle()
                        .fill(palette.accentGradient)
                        .frame(width: 5, height: 5)
                    Text("#\(run.number) \(run.branch ?? "") · \(run.status.label)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text(shortDuration(run))
                        .font(.metric(11))
                        .foregroundStyle(palette.textTertiary)
                }
            }
            if active.count > 3 {
                HStack {
                    Text("还有 \(active.count - 3) 条")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                    Spacer()
                }
            }
        }
    }

    // MARK: 文案与配色

    private var durationText: String {
        guard let latest else { return "—" }
        guard let start = latest.startedAt else { return "排队" }
        let end = latest.isActive ? Date() : latest.updatedAt
        return shortDuration(from: start, to: end)
    }

    private var subMetric: String {
        guard let latest else { return "" }
        if latest.isActive { return "RUNNING" }
        if let artifact { return artifact.sizeText }
        return latest.conclusion.label.uppercased()
    }

    private var ratio: Double {
        guard let latest else { return 0 }
        if latest.isActive { return 0.55 }
        return latest.conclusion == .success ? 1 : 0.7
    }

    private var barFill: some ShapeStyle {
        guard let latest, latest.isActive else {
            return latest?.conclusion == .failure
                ? AnyShapeStyle(palette.failure.opacity(0.8))
                : AnyShapeStyle(palette.textPrimary.opacity(0.45))
        }
        return AnyShapeStyle(palette.accentGradient)
    }

    private var pillText: String {
        guard let latest else { return "NO RUN" }
        if latest.isActive { return "RUNNING" }
        if artifact != nil { return "PACKAGE READY" }
        return latest.conclusion.label.uppercased()
    }

    private var pillColor: Color {
        guard let latest else { return palette.textTertiary }
        if latest.isActive { return palette.accentStart }
        if latest.conclusion == .failure { return palette.failure }
        if artifact != nil { return palette.textSecondary }
        return palette.textTertiary
    }

    private var caption: String {
        if let error = environmentError {
            return error.localizedDescription
        }
        guard let latest else { return "还没有构建记录" }
        if latest.isActive { return "构建中 · 已运行 \(shortDuration(latest))" }
        if artifact != nil { return "\(relative(latest.updatedAt)) · IPA 已就绪" }
        return "\(latest.conclusion.label) · \(relative(latest.updatedAt))"
    }

    private var environmentError: AppError? {
        environment.monitor.errors[repo.fullName]
    }

    // MARK: 工具

    private func shortDuration(_ run: RunRecord) -> String {
        guard let start = run.startedAt else { return "—" }
        return shortDuration(from: start, to: run.isActive ? Date() : run.updatedAt)
    }

    private func shortDuration(from start: Date, to end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(start)))
        let minutes = total / 60
        let seconds = total % 60
        return minutes > 0 ? "\(minutes):\(String(format: "%02d", seconds))" : "\(seconds)s"
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func score(_ name: String) -> Int {
        let lowered = name.lowercased()
        if lowered.contains("ipa") { return 2 }
        if lowered.contains("unsigned") || lowered.contains("build") { return 1 }
        return 0
    }
}
