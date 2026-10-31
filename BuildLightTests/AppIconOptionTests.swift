import Testing
import Foundation
@testable import BuildLight

/// 图标选择状态的解析。
///
/// 这条逻辑的坑在于：`UIApplication.alternateIconName` 在自签重打包的包上
/// 不可靠，退到后台再回来可能读成 nil。界面上表现为「明明换了图标，
/// 选中的框却跳回原色」。
struct AppIconOptionTests {
    @Test("系统值可识别时以系统为准")
    func systemWins() {
        #expect(AppIconOption.resolve(systemName: "AppIcon-Rose", storedRaw: "indigo") == .rose)
    }

    @Test("系统值为 nil 时用本地记录兜底")
    func fallsBackToStored() {
        #expect(AppIconOption.resolve(systemName: nil, storedRaw: "pine") == .pine)
    }

    @Test("两者都没有 → 原色")
    func defaults() {
        #expect(AppIconOption.resolve(systemName: nil, storedRaw: nil) == .default)
    }

    @Test("系统值匹配不上任何图标 → 原色，不要误判成别的")
    func unknownSystemName() {
        #expect(AppIconOption.resolve(systemName: "AppIcon-Legacy", storedRaw: "rose") == .default)
    }

    @Test("本地记录损坏 → 原色")
    func corruptedStoredValue() {
        #expect(AppIconOption.resolve(systemName: nil, storedRaw: "not-a-color") == .default)
    }

    @Test("备用图标名映射正确")
    func alternateNames() {
        #expect(AppIconOption.rose.alternateName == "AppIcon-Rose")
        #expect(AppIconOption.copper.alternateName == "AppIcon-Copper")
        #expect(AppIconOption.default.alternateName == nil)
    }

    @Test("七套彩色图标都有名字")
    func allColorsHaveNames() {
        let colored = AppIconOption.allCases.filter { $0 != .default }
        #expect(colored.count == 7)
        #expect(colored.allSatisfy { $0.alternateName != nil })
        // 名字不能重复，否则系统会认错
        let names = Set(colored.compactMap(\.alternateName))
        #expect(names.count == 7)
    }
}
