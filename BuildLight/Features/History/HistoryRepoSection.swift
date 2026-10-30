import SwiftUI

/// 历史页里的一个可折叠仓库分组。
///
/// 为什么默认折叠：
/// 21 个仓库 × 每个几十条记录，全展开要滑很久才能找到目标。
/// 折叠后一屏能看到六七个仓库的最新状态，点开才展开明细——
/// 这是「先定位仓库，再看记录」的自然顺序。
struct HistoryRepoSection: View {
    @Environment(\.accent) private var accent
    let group: HistoryRepoGroup
    @Binding var expandedRepoIDs: Set<String>

    private var isExpanded: Bool {
        expandedRepoIDs.contains(group.id)
    }

    private var latest: RunRecord? {
        group.runs.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isExpanded {
                ForEach(group.runs) { run in
                    ZStack(alignment: .bottom) {
                        NavigationLink(value: RunRoute(runID: run.id)) {
                            RunRowView(run: run)
                        }
                        .buttonStyle(PressableStyle())
                        Hairline(leading: DS.pad)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var header: some View {
        Button {
            withAnimation(Motion.settle) {
                if isExpanded {
                    expandedRepoIDs.remove(group.id)
                } else {
                    expandedRepoIDs.insert(group.id)
                }
            }
        } label: {
            HStack(spacing: 10) {
                statusDot

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displayName)
                        .font(Type.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(Type.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("\(group.runs.count)")
                    .font(Type.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, DS.pad)
            .padding(.top, 16)
            .padding(.bottom, 10)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(group.displayName)，\(group.runs.count) 条记录")
        .accessibilityHint(isExpanded ? "收起" : "展开")
    }

    private var statusDot: some View {
        Group {
            if latest?.isActive == true {
                PulsingDot(color: accent.primary, size: 5)
            } else if latest.map(isFailed) == true {
                Image(systemName: "xmark")
                    .scaledFont(size: 8, weight: .black)
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

    private func isFailed(_ run: RunRecord) -> Bool {
        run.conclusion == .failure || run.conclusion == .timedOut
    }

    private var subtitle: String {
        guard let latest else { return "暂无记录" }
        var parts: [String] = []
        if let workflow = latest.workflowName, !workflow.isEmpty { parts.append(workflow) }
        parts.append(RelativeTime.text(for: latest.createdAt))
        return parts.joined(separator: " · ")
    }
}
