import Foundation
import Observation
import SwiftUI

/// 外观设置：强调色 + 是否减弱动态效果。
///
/// 用 `@Observable` 而不是 `@AppStorage`：后者在这个类里不会触发视图刷新，
/// 所以持久化自己写 `UserDefaults`，值本身才是唯一事实源。
@MainActor
@Observable
final class AppearanceStore {
    private enum Keys {
        static let theme = "accentTheme"
        static let reduceMotion = "reduceMotionOverride"
    }

    var theme: AccentTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    /// 用户手动关掉动效。系统「减弱动态效果」仍然优先。
    var reduceMotionEnabled: Bool {
        didSet { defaults.set(reduceMotionEnabled, forKey: Keys.reduceMotion) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Keys.theme) ?? AccentTheme.indigo.rawValue
        self.theme = AccentTheme(rawValue: raw) ?? .indigo
        self.reduceMotionEnabled = defaults.bool(forKey: Keys.reduceMotion)
    }

    /// 组装当前生效的强调色集合。
    func accent(for scheme: ColorScheme) -> Accent {
        Accent(theme: theme, scheme: scheme)
    }
}

/// 一次具体的强调色解析结果。视图拿它而不是拿主题枚举，
/// 免得每个视图都要自己判断浅色深色。
struct Accent {
    let theme: AccentTheme
    let scheme: ColorScheme

    var primary: Color { theme.primary(for: scheme) }
    var soft: Color { primary.opacity(0.14) }
    var wash: Color { theme.wash(for: scheme) }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primary, primary.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct AccentKey: EnvironmentKey {
    static let defaultValue = Accent(theme: .indigo, scheme: .light)
}

extension EnvironmentValues {
    var accent: Accent {
        get { self[AccentKey.self] }
        set { self[AccentKey.self] = newValue }
    }
}
