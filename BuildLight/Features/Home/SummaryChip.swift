import SwiftUI

/// iOS 26 玻璃胶囊。放在 `GlassEffectContainer` 里使用。
struct SummaryChip: View {
    let title: String
    let systemImage: String
    let isProminent: Bool

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(isProminent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: .capsule)
    }
}
