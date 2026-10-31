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

    /// 当前系统上生效的图标。
    static var current: AppIconOption {
        guard let name = UIApplication.shared.alternateIconName else { return .default }
        return allCases.first { $0.alternateName == name } ?? .default
    }
}
