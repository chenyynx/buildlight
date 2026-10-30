import SwiftUI

/// 全 App 的动效节奏。集中在这里，避免每个视图各写一套时长。
///
/// 「减弱动态效果」由 `motionAware` 统一处理：开启时换成淡入淡出，
/// 不做位移和缩放。
enum Motion {
    /// 按下反馈：短、脆。
    static let press = Animation.spring(response: 0.26, dampingFraction: 0.82)
    /// 状态切换：卡片入场、选中态迁移。
    static let settle = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// 连续循环动画（呼吸、跑马灯）。
    static let loop = Animation.easeInOut(duration: 0.9)
    /// 数值/进度变化。
    static let smooth = Animation.easeOut(duration: 0.22)
}

/// 让动效尊重系统的「减弱动态效果」。
struct MotionPreferenceKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var reducesMotion: Bool {
        get { self[MotionPreferenceKey.self] }
        set { self[MotionPreferenceKey.self] = newValue }
    }
}

extension View {
    /// 在「减弱动态效果」开启时把弹性动画降级为纯淡入淡出。
    func motionAware(_ animation: Animation) -> some View {
        modifier(MotionAwareModifier(animation: animation))
    }
}

private struct MotionAwareModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.reducesMotion) private var userReduceMotion
    let animation: Animation

    func body(content: Content) -> some View {
        let reduced = systemReduceMotion || userReduceMotion
        content.animation(reduced ? .easeOut(duration: 0.16) : animation)
    }
}
