import SwiftUI

struct HistorySectionHeader: View {
    let group: HistoryRepoGroup

    var body: some View {
        HStack(spacing: Metrics.xs + 2) {
            Image(systemName: "shippingbox.fill")
                .font(.caption2)
                .foregroundStyle(Accent.primary)
            Text(group.displayName)
                .font(.tag)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(group.runs.count) 次")
                .font(.tag)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .textCase(nil)
    }
}
