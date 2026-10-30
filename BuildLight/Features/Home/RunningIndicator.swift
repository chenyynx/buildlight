import SwiftUI

/// 呼吸点：中心实心 + 一圈向外扩散的余晖。
/// 只驱动一个 14pt 的圆，开销可以忽略，不要套在整张卡上做动画。
struct PulsingDot: View {
    var color: Color = StatusTone.running
    var size: CGFloat = 7

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .fill(color.opacity(0.35))
                    .frame(width: size * 2, height: size * 2)
                    .scaleEffect(animating ? 1.6 : 0.5)
                    .opacity(animating ? 0 : 1)
            }
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .frame(width: size * 2.4, height: size * 2.4)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
                animating = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// 不确定进度的跑马灯：一道高光从左扫到右，表示「在动，但不知道还剩多久」。
/// GitHub 不给实时百分比，假装一个进度反而更糟。
struct IndeterminateBar: View {
    var color: Color = StatusTone.running
    var height: CGFloat = 4
    var duration: Double = 1.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.45

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            Capsule()
                .fill(color.opacity(reduceMotion ? 0.55 : 0.16))
                .overlay(alignment: .leading) {
                    if !reduceMotion {
                        Capsule()
                            .fill(color)
                            .frame(width: width * 0.38)
                            .offset(x: width * phase)
                    }
                }
                .clipShape(Capsule())
        }
        .frame(height: height)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                phase = 1.02
            }
        }
        .accessibilityHidden(true)
    }
}
