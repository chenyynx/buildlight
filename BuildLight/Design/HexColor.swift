import SwiftUI

/// 十六进制色。只在设计 token 层用；视图层一律拿语义色。
extension Color {
    /// #RGB / #RRGGBB / #RRGGBBAA
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    init(hexString: String, alpha: Double = 1) {
        let cleaned = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        var value: UInt32 = 0
        Scanner(string: cleaned).scanHexInt32(&value)
        self.init(hex: value, alpha: alpha)
    }
}
