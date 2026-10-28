import SwiftUI

struct HomeHeader: View {
    let repos: [RepoRecord]

    var body: some View {
        HStack(spacing: Metrics.s) {
            SummaryChip(
                title: "\(activeCount) 个在跑",
                systemImage: "bolt.fill",
                isProminent: activeCount > 0
            )
            if failingCount > 0 {
                SummaryChip(
                    title: "\(failingCount) 个失败",
                    systemImage: "exclamationmark.triangle.fill",
                    isProminent: false
                )
            }
            SummaryChip(
                title: "\(repos.count) 个仓库",
                systemImage: "shippingbox.fill",
                isProminent: false
            )
        }
        .padding(.horizontal, Metrics.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeCount: Int {
        repos.reduce(0) { $0 + $1.activeRunCount }
    }

    private var failingCount: Int {
        repos.filter(\.latestFailed).count
    }
}
