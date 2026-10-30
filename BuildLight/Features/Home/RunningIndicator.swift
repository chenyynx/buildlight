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

/// 不确定进度的「光带」。
///
/// GitHub 不给实时百分比，假装一个进度反而更糟，
/// 所以这里表达的是「在动」而不是「完成了多少」。
///
/// **为什么是一条贴着卡底边的光带**：
/// 旧版把它塞在卡片内边距里，左右各缩进 16pt，
/// 既没对齐圆角、又在浅色卡上露出一条硬邦邦的浅色轨，
/// 看起来像排版错误而不是进度指示。
/// 现在整条贴在卡片底边、由卡片自己的圆角裁剪，
/// 光带两端淡出，不做轨道、不做胶囊——
/// 它读起来是卡片在「呼吸」，而不是一个没做完的进度条。
struct IndeterminateBar: View {
    var color: Color = StatusTone.running
    var height: CGFloat = 3
    var duration: Double = 2.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.5

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .leading) {
                // 常驻的极淡底光：静态时也能看出这条边是「活的」
                LinearGradient(
                    colors: [color.opacity(0.06), color.opacity(0.16), color.opacity(0.06)],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                if !reduceMotion {
                    LinearGradient(
                        stops: [
                            .init(color: color.opacity(0), location: 0),
                            .init(color: color.opacity(0.55), location: 0.35),
                            .init(color: color, location: 0.5),
                            .init(color: color.opacity(0.55), location: 0.65),
                            .init(color: color.opacity(0), location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.55)
                    .offset(x: width * phase)
                }
            }
        }
        .frame(height: height)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
        }
        .accessibilityHidden(true)
    }
}
