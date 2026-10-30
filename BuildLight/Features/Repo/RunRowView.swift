import SwiftUI

/// 一条构建记录。首页之外的所有列表都用它。
struct RunRowView: View {
    @Environment(\.accent) private var accent
    let run: RunRecord

    var body: some View {
        HStack(spacing: 12) {
            statusDot

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                Text(meta)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(duration)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(tone ?? .secondary)
                Text(whenText)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, DS.pad)
        .padding(.vertical, DS.rowVertical)
    }

    private var statusDot: some View {
        Group {
            if run.isActive {
                PulsingDot(color: accent.primary, size: 5)
            } else if isFailed {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(StatusTone.failed, in: .circle)
            } else {
                Circle()
                    .strokeBorder(StatusTone.idle.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 11, height: 11)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }

    private var title: String {
        run.title ?? run.workflowName ?? "#\(run.number)"
    }

    private var meta: String {
        var parts = ["#\(run.number)"]
        if let workflow = run.workflowName, !workflow.isEmpty, run.title != nil {
            parts.append(workflow)
        }
        if let branch = run.branch, !branch.isEmpty { parts.append(branch) }
        return parts.joined(separator: " · ")
    }

    private var duration: String {
        guard let start = run.startedAt else {
            return run.isActive ? "排队" : "—"
        }
        let end = run.isActive ? Date.now : run.updatedAt
        let total = max(0, Int(end.timeIntervalSince(start)))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    private var whenText: String {
        if run.isActive { return run.status.label }
        return RelativeTime.text(for: run.createdAt)
    }

    private var isFailed: Bool {
        run.conclusion == .failure || run.conclusion == .timedOut
    }

    private var tone: Color? {
        if run.isActive { return accent.primary }
        if isFailed { return StatusTone.failed }
        return nil
    }
}
