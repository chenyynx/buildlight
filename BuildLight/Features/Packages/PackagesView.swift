import SwiftUI

/// 产物页：所有已经下载到本机的安装包。
///
/// 单独一个 tab 的理由：用户装 App 的目的就是「把包弄到手机上装」。
/// 这个动作和「看构建进度」是两种心智，混在一个列表里会让两边都变难用。
struct PackagesView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    PackagesSummaryPanel(
                        count: environment.cache.entries.count,
                        totalSize: environment.cache.totalSizeText
                    )
                    .padding(.top, 4)

                    if environment.cache.entries.isEmpty {
                        ContentUnavailableView {
                            Label("还没有下载过包", systemImage: "shippingbox")
                        } description: {
                            Text("在构建页点下载，包会存到这里")
                        }
                        .padding(.top, 48)
                    } else {
                        SectionLabel("已下载", trailing: "\(environment.cache.entries.count)")
                        ForEach(environment.cache.entries) { entry in
                            PackageEntryCard(entry: entry)
                                .padding(.horizontal, DS.pad)
                                .padding(.bottom, 10)
                        }
                    }
                }
                .padding(.bottom, Metrics.tabBarClearance)
            }
            .scrollIndicators(.hidden)
            .background(PaperBackground())
            .navigationTitle("产物")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !environment.cache.entries.isEmpty {
                        Button("清空", role: .destructive) {
                            showingClearConfirmation = true
                        }
                    }
                }
            }
            .confirmationDialog(
                "清空后需要重新下载",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("清空全部", role: .destructive) {
                    environment.cache.clearAll()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("当前占用 \(environment.cache.totalSizeText)")
            }
        }
    }
}
