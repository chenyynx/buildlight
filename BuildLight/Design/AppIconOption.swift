import SwiftUI
import UIKit

/// 主屏图标可选颜色。
///
/// 七套彩色图标在 Assets 里各是一个 appiconset，
/// 并在 `Info.plist` 的 `CFBundleAlternateIcons` 里登记。
/// 切换走 `UIApplication.setAlternateIconName`，系统会弹一次确认提示——
/// 这是 iOS 的硬性行为，无法绕过，也不需要绕过。
enum AppIconOption: String, CaseIterable, Identifiable, Sendable {
    case `default`
    case indigo
    case violet
    case rose
    case teal
    case pine
    case lime
    case copper

    var id: String { rawValue }

    /// 传给系统的备用图标名。`default` 用 nil 表示回到原始图标。
    var alternateName: String? {
        self == .default ? nil : "AppIcon-\(rawValue.capitalized)"
    }

    var title: String {
        switch self {
        case .default: "原色"
        case .indigo: "靛蓝"
        case .violet: "紫罗兰"
        case .rose: "玫瑰"
        case .teal: "湖蓝"
        case .pine: "松绿"
        case .lime: "青柠"
        case .copper: "赤铜"
        }
    }

    /// 用于在设置页画色块的参考色（与图标底色一致）。
    var swatch: Color? {
        switch self {
        case .default: nil
        case .indigo: Color(hex: 0x3A5BD0)
        case .violet: Color(hex: 0x7A4BD1)
        case .rose: Color(hex: 0xC7447C)
        case .teal: Color(hex: 0x0F7F92)
        case .pine: Color(hex: 0x2C7A55)
        case .lime: Color(hex: 0x6B8A1E)
        case .copper: Color(hex: 0xA55A2C)
        }
    }

    /// 本地记录。
    ///
    /// **为什么不能只信 `UIApplication.shared.alternateIconName`**：
    /// 它在自签重打包的包上不可靠——设置成功后能读到，
    /// 但 App 退到后台再回来时可能返回 nil，
    /// 界面就会被判成「原色」，而主屏上明明是彩色的。
    /// 所以这里自己存一份，读的时候以系统值为准、读不到再退回本地记录。
    private static let storageKey = "selectedAppIconOption"

    var isInstalled: Bool {
        UIApplication.shared.alternateIconName != nil || self == .default
    }

    /// 当前生效的图标。系统值优先，取不到用本地记录兜底。
    static var current: AppIconOption {
        resolve(
            systemName: UIApplication.shared.alternateIconName,
            storedRaw: UserDefaults.standard.string(forKey: storageKey)
        )
    }

    /// 纯解析（可单测）。
    ///
    /// 三种情况：
    /// 1. 系统给了可识别的名字 → 听系统的
    /// 2. 系统给了名字但匹配不上（旧版本残留 / 图标被移除）→ 原色
    /// 3. 系统给 nil（自签包常见的回读失败）→ 用本地记录，再没有就原色
    static func resolve(systemName: String?, storedRaw: String?) -> AppIconOption {
        if let systemName {
            return allCases.first { $0.alternateName == systemName } ?? .default
        }
        if let storedRaw, let stored = AppIconOption(rawValue: storedRaw) {
            return stored
        }
        return .default
    }

    /// 切换成功后落一份本地记录。
    static func remember(_ option: AppIconOption) {
        UserDefaults.standard.set(option.rawValue, forKey: storageKey)
    }
}
