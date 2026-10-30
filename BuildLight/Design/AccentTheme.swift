import SwiftUI

/// 七款可切换的强调色。
///
/// 强调色只负责「交互」——按钮、选中态、进度、聚焦环。
/// 「状态」（在跑 / 失败）永远用固定色，不跟随强调色，
/// 否则用户把强调色切到红色时，「在跑」和「失败」会长得一样。
enum AccentTheme: String, CaseIterable, Identifiable, Sendable {
    case indigo
    case violet
    case rose
    case teal
    case pine
    case lime
    case copper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .indigo: "靛蓝"
        case .violet: "紫罗兰"
        case .rose: "玫瑰"
        case .teal: "湖蓝"
        case .pine: "松绿"
        case .lime: "青柠"
        case .copper: "赤铜"
        }
    }

    /// 浅色模式下的主色。
    var light: Color {
        switch self {
        case .indigo: Color(hex: 0x3A5BD0)
        case .violet: Color(hex: 0x7A4BD1)
        case .rose: Color(hex: 0xC7447C)
        case .teal: Color(hex: 0x0F7F92)
        case .pine: Color(hex: 0x2C7A55)
        case .lime: Color(hex: 0x6B8A1E)
        case .copper: Color(hex: 0xA55A2C)
        }
    }

    /// 深色模式下的主色。同一色相但提亮，保证在近黑背景上仍然够清晰。
    var dark: Color {
        switch self {
        case .indigo: Color(hex: 0x93A6FF)
        case .violet: Color(hex: 0xBCA0FF)
        case .rose: Color(hex: 0xFF97BC)
        case .teal: Color(hex: 0x54D4E2)
        case .pine: Color(hex: 0x74D6A6)
        case .lime: Color(hex: 0xC2DC58)
        case .copper: Color(hex: 0xE8A06A)
        }
    }

    func primary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? dark : light
    }

    /// 背景上的大色晕。玻璃要折射出东西，背后得有东西。
    func wash(for scheme: ColorScheme) -> Color {
        primary(for: scheme).opacity(scheme == .dark ? 0.16 : 0.08)
    }
}
