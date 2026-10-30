import SwiftUI

/// 下载进度条。用容器宽度算比例，带最小可见宽度，
/// 进度为 0 时也能看出「已经在下了」。
struct DownloadProgressBar: View {
    let progress: Double
    var height: CGFloat = 6
    var tint: Color?

    @Environment(\.accent) private var accent

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(tint ?? accent.primary)
                    .frame(width: max(height, width * clamped))
            }
        }
        .frame(height: height)
        .animation(Motion.smooth, value: clamped)
        .accessibilityElement()
        .accessibilityLabel("下载进度")
        .accessibilityValue("\(Int(clamped * 100))%")
    }
}

/// 环形进度，给按钮位置用：外圈轨道 + 内圈进度 + 居中符号。
///
/// 下载时可点（暂停），暂停时显示播放三角。
struct DownloadRing: View {
    let progress: Double
    var size: CGFloat = 30
    var lineWidth: CGFloat = 3
    /// 传 nil 就是纯展示（不可点）。
    var symbol: String?

    @Environment(\.accent) private var accent

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(accent.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.smooth, value: clamped)
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(accent.primary)
            } else {
                Text("\(Int(clamped * 100))")
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(symbol == "pause.fill" ? "暂停下载" : "下载进度")
        .accessibilityValue("\(Int(clamped * 100))%")
    }
}
