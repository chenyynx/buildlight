import SwiftUI

/// 已下载产物的明细：每个包多大、什么时候下的、单独删还是全清。
struct CacheView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showingClearConfirmation = false
    @State private var showingClearedAlert = false
    @State private var freedText = ""

    var body: some View {
        List {
            Section {
                LabeledContent("占用空间", value: environment.cache.totalSizeText)
                LabeledContent("包数量", value: "\(environment.cache.entries.count)")
            } footer: {
                Text("包保存在 App 自己的目录里，导入全能签后可以随时删掉。")
            }

            if environment.cache.entries.isEmpty {
                Section {
                    ContentUnavailableView(
                        "还没有下载过包",
                        systemImage: "shippingbox",
                        description: Text("在构建卡片上点下载按钮，包会存到这里")
                    )
                }
            } else {
                Section("已下载") {
                    ForEach(environment.cache.entries) { entry in
                        row(entry)
                            .swipeActions {
                                Button("删除", role: .destructive) {
                                    environment.cache.remove(entry.id)
                                }
                            }
                    }
                }

                Section {
                    Button("清空全部", role: .destructive) {
                        showingClearConfirmation = true
                    }
                }
            }
        }
        .navigationTitle("缓存")
        .confirmationDialog("清空后需要重新下载", isPresented: $showingClearConfirmation) {
            Button("清空全部", role: .destructive) {
                let freed = environment.cache.clearAll()
                freedText = ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)
                showingClearedAlert = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前占用 \(environment.cache.totalSizeText)")
        }
        .alert("已清空", isPresented: $showingClearedAlert) {
            Button("好") {}
        } message: {
            Text("释放了 \(freedText)")
        }
    }

    private func row(_ entry: CacheStore.Entry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.fileName)
                .font(.subheadline)
                .lineLimit(1)
            Text("\(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)) · \(entry.savedAt.formatted(.relative(presentation: .named)))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
