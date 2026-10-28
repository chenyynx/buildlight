import SwiftUI

/// 下载进度条。用容器宽度算比例，带最小可见宽度，
/// 进度为 0 时也能看出「已经在下了」。
struct DownloadProgressBar: View {
    let progress: Double
    var height: CGFloat = 6
    var tint: Color = Accent.primary

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, width * clamped))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.18), value: clamped)
        .accessibilityElement()
        .accessibilityLabel("下载进度")
        .accessibilityValue("\(Int(clamped * 100))%")
    }
}

/// 环形进度，给按钮位置用：外圈轨道 + 内圈进度 + 居中百分比。
struct DownloadRing: View {
    let progress: Double
    var size: CGFloat = 30
    var lineWidth: CGFloat = 3

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(Accent.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.18), value: clamped)
            Text("\(Int(clamped * 100))")
                .font(.system(size: 9, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("下载进度")
        .accessibilityValue("\(Int(clamped * 100))%")
    }
}
