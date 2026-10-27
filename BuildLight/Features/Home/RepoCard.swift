import SwiftUI
import SwiftData

/// 首页卡片。视觉按参考图，交互控件仍是系统原生的（NavigationLink / Button / ShareLink）。
struct RepoCard: View {
    @Environment(AppEnvironment.self) private var environment
    let repo: RepoRecord
    let palette: Palette

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
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(repo.displayName)
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    MicroLabel(text: subtitle, color: palette.textSecondary)
                }
                Spacer(minLength: 8)
                statusPill
            }

            HStack(alignment: .firstTextBaseline) {
                Text(durationText)
                    .font(.display(27))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text(metricText)
                    .font(.system(size: 10.5, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(palette.textTertiary)
            }
            .padding(.top, 13)

            progressBar.padding(.top, 12)

            HStack(spacing: 10) {
                Text(caption)
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let artifact, let run = latest {
                    PackageButton(artifact: artifact, run: run)
                }
            }
            .padding(.top, 12)

            if active.count > 1 {
                Divider().overlay(palette.hairline).padding(.top, 12)
                VStack(spacing: 7) {
                    ForEach(active.dropFirst().prefix(2)) { run in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(palette.accentGradient)
                                .frame(width: 5, height: 5)
                            Text("#\(run.number) \(run.branch ?? "") · \(run.status.label)")
                                .font(.system(size: 11.5))
                                .foregroundStyle(palette.textSecondary)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(shortDuration(run))
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(palette.textTertiary)
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(16)
        .background(palette.surface, in: .rect(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(palette.hairline, lineWidth: 0.5)
        }
        .contentShape(.rect(cornerRadius: 26))
    }

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
                Capsule().fill(palette.textPrimary.opacity(0.09))
                Capsule()
                    .fill(barStyle)
                    .frame(width: max(0, proxy.size.width * ratio))
            }
        }
        .frame(height: 3)
    }

    private var barStyle: AnyShapeStyle {
        guard let latest else { return AnyShapeStyle(palette.textTertiary) }
        if latest.isActive { return AnyShapeStyle(palette.accentGradient) }
        if latest.conclusion == .failure { return AnyShapeStyle(palette.failure.opacity(0.85)) }
        if latest.conclusion == .success { return AnyShapeStyle(palette.textPrimary.opacity(0.45)) }
        return AnyShapeStyle(palette.textTertiary)
    }

    private var ratio: Double {
        guard let latest else { return 0 }
        if latest.isActive { return 0.55 }
        return latest.conclusion == .success ? 1 : 0.75
    }

    private var subtitle: String {
        guard let latest else { return "NO RUN" }
        return [latest.workflowName, latest.branch].compactMap { $0 }.joined(separator: " · ")
    }

    private var durationText: String {
        guard let latest else { return "—" }
        guard let start = latest.startedAt else { return "排队" }
        let end = latest.isActive ? Date() : latest.updatedAt
        let total = max(0, Int(end.timeIntervalSince(start)))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    private var metricText: String {
        guard let latest else { return "" }
        if latest.isActive { return "RUNNING" }
        if let artifact { return artifact.sizeText.uppercased() }
        return latest.conclusion.label.uppercased()
    }

    private var caption: String {
        if let error = environment.monitor.errors[repo.fullName] {
            return error.localizedDescription
        }
        guard let latest else { return "还没有构建记录" }
        if latest.isActive { return "\(latest.status.label) · #\(latest.number)" }
        if artifact != nil { return "\(relative(latest.updatedAt)) · IPA 已就绪" }
        return "\(latest.conclusion.label) · \(relative(latest.updatedAt))"
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

    private func shortDuration(_ run: RunRecord) -> String {
        guard let start = run.startedAt else { return "—" }
        let total = max(0, Int((run.isActive ? Date() : run.updatedAt).timeIntervalSince(start)))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
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
