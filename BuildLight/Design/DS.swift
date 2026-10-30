import SwiftUI

/// 全局排版规则。所有页面只用这里面的积木，避免每页各写一套。
///
/// 规则：
/// - 左右边距 20，分组标题 11pt 宽字距
/// - 数字一律等宽（monospacedDigit），避免跳动
/// - 分隔用 0.5pt 发丝线，不用卡片、不用阴影
/// - 只有两个信号色：琥珀=在跑，砖红=失败
enum DS {
    static let pad: CGFloat = 20
    static let rowVertical: CGFloat = 13
}

struct SectionLabel: View {
    let title: String
    var trailing: String?

    init(_ title: String) {
        self.title = title
    }

    init(_ title: String, trailing: String?) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, DS.pad)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }
}

struct Hairline: View {
    var leading: CGFloat = DS.pad

    var body: some View {
        Rectangle()
            .fill(.quaternary.opacity(0.55))
            .frame(height: 0.5)
            .padding(.leading, leading)
    }
}

struct ScreenHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.6)
                .lineLimit(2)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.pad)
        .padding(.top, 10)
    }
}

/// 一个大数字 + 一个小标题。首页顶部、详情页头部都用它。
struct MetricCell: View {
    let value: String
    let label: String
    var tint: Color?
    var size: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: size, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint ?? .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VerticalRule: View {
    var height: CGFloat = 28

    var body: some View {
        Rectangle()
            .fill(.quaternary.opacity(0.6))
            .frame(width: 0.5, height: height)
    }
}

/// 整行主按钮。详情页取包、设置页关键动作都用它。
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var tint: Color?
    let action: () -> Void

    @Environment(\.accent) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(tint ?? accent.primary, in: .rect(cornerRadius: 13))
        }
        .buttonStyle(PressableStyle())
    }
}

/// 设置页 / 详情页的功能行：图标块 + 标题 + 右侧值。
struct FunctionRow: View {
    let systemImage: String
    var tint: Color = .secondary
    let title: String
    var value: String?
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(tint, in: .rect(cornerRadius: 7))

            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(.rect)
    }
}

/// 把一组行包成一个圆角容器——只用在设置这类低频页面，列表页不要用。
struct GroupBox2<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(.quaternary.opacity(0.22), in: .rect(cornerRadius: 16))
        .padding(.horizontal, DS.pad)
    }
}
