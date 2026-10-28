import SwiftUI

struct HomeHeader: View {
    let repos: [RepoRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
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
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeCount: Int {
        repos.reduce(0) { $0 + $1.runs.filter(\.isActive).count }
    }

    /// 只看每个仓库最近一条，避免历史上出现过失败就永远计数。
    private var failingCount: Int {
        repos.filter { repo in
            repo.runs.max(by: { $0.createdAt < $1.createdAt })?.conclusion == .failure
        }.count
    }
}
