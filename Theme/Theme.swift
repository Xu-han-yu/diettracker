//
//  Theme.swift
//  DietTracker
//
//  主题容器 + Environment 注入 + 视图修饰符 + 状态→颜色映射。
//
//  ⚠️ 规则：本文件不定义任何原始色值 / 字号 / 尺寸，一律引用 Tokens.*。
//     业务视图（第 6 步）只允许使用本文件提供的 dtXxx 修饰符与 DTXxx 组件。
//

import SwiftUI

// MARK: - Theme

/// 主题容器。颜色本身由 Tokens 提供动态值（自动适配浅色 / 深色），
/// 这里只承载「可切换的形态参数」——圆角档位、信息密度、图表网格开关。
struct Theme: Equatable {

    enum CornerStyle: String, CaseIterable {
        case small, medium, large
    }

    enum Density: String, CaseIterable {
        case compact, medium, comfortable
    }

    var cornerStyle: CornerStyle
    var density: Density
    var accentName: String
    var showsChartGrid: Bool

    // MARK: 派生值

    var cardRadius: CGFloat {
        switch cornerStyle {
        case .small:  return Tokens.Radius.md
        case .medium: return Tokens.Radius.lg
        case .large:  return Tokens.Radius.lg + 4
        }
    }

    var cardPadding: CGFloat {
        switch density {
        case .compact:     return Tokens.Space.sm
        case .medium:       return Tokens.Space.md
        case .comfortable:  return Tokens.Space.lg
        }
    }

    var cardSpacing: CGFloat {
        switch density {
        case .compact:     return Tokens.Space.sm
        case .medium:       return Tokens.Space.lg
        case .comfortable:  return Tokens.Space.xl
        }
    }

    var sectionSpacing: CGFloat {
        switch density {
        case .compact:     return Tokens.Space.md
        case .medium:       return Tokens.Space.xl
        case .comfortable:  return Tokens.Space.xxl
        }
    }
}

extension Theme {
    /// 项目默认主题：中等圆角、中等密度、冷蓝强调色、显示图表网格。
    static let `default` = Theme(
        cornerStyle: .medium,
        density: .medium,
        accentName: "CoolBlue",
        showsChartGrid: true
    )
}

// MARK: - Environment 注入

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Theme = .default
}

extension EnvironmentValues {
    var dtTheme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - 状态 → 颜色（全项目唯一映射处）

extension NutrientStatus {
    var dtColor: Color {
        switch self {
        case .sufficient: return Tokens.Palette.Status.sufficient
        case .low:        return Tokens.Palette.Status.low
        case .high:       return Tokens.Palette.Status.high
        case .none:       return Tokens.Palette.Status.none
        }
    }
}

// MARK: - ViewModifiers

/// 标准卡片：surface 底 + 0.5px 细边框，无阴影。
private struct DTCard: ViewModifier {
    @Environment(\.dtTheme) private var theme
    let padding: CGFloat?

    func body(content: Content) -> some View {
        let p = padding ?? theme.cardPadding
        let shape = RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
        return content
            .padding(p)
            .background(Tokens.Palette.surface)
            .clipShape(shape)
            .overlay(shape.stroke(Tokens.Palette.separator, lineWidth: Tokens.Border.hairline))
    }
}

/// 指标块：surfaceMuted 底，无边框。用于卡片内的次要数据块。
private struct DTMutedSurface: ViewModifier {
    let padding: CGFloat?

    func body(content: Content) -> some View {
        let p = padding ?? Tokens.Space.sm
        return content
            .padding(p)
            .background(Tokens.Palette.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }
}

/// 数字样式：强制等宽数字 + Dynamic Type 限幅。
private struct DTNumber: ViewModifier {
    let font: Font
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .dynamicTypeSize(Tokens.Typography.minDynamicTypeSize...Tokens.Typography.maxDynamicTypeSize)
    }
}

/// 主按钮：石墨黑实心（对应视觉稿的「分析今天」）。
private struct DTPrimaryButton: ViewModifier {
    @Environment(\.dtTheme) private var theme

    func body(content: Content) -> some View {
        content
            .font(Tokens.Typography.headline)
            .foregroundStyle(Tokens.Palette.surface)
            .padding(.vertical, Tokens.Space.sm)
            .frame(maxWidth: .infinity)
            .background(Tokens.Palette.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous))
    }
}

/// 次按钮：surface 底 + 1px 边框。
private struct DTSecondaryButton: ViewModifier {
    @Environment(\.dtTheme) private var theme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
        return content
            .font(Tokens.Typography.headline)
            .foregroundStyle(Tokens.Palette.textPrimary)
            .padding(.vertical, Tokens.Space.sm)
            .frame(maxWidth: .infinity)
            .background(Tokens.Palette.surface)
            .clipShape(shape)
            .overlay(shape.stroke(Tokens.Palette.separatorStrong, lineWidth: Tokens.Border.thin))
    }
}

// MARK: - View 扩展

extension View {

    /// 在根视图注入主题。
    func dtTheme(_ theme: Theme) -> some View {
        environment(\.dtTheme, theme)
    }

    /// 页面底色（含 ignoresSafeArea）。
    func dtScreenBackground() -> some View {
        background(Tokens.Palette.background.ignoresSafeArea())
    }

    /// 页面左右留白。
    func dtScreenPadding() -> some View {
        padding(.horizontal, Tokens.Layout.screenPadding)
    }

    func dtCard(padding: CGFloat? = nil) -> some View {
        modifier(DTCard(padding: padding))
    }

    func dtSurfaceMuted(padding: CGFloat? = nil) -> some View {
        modifier(DTMutedSurface(padding: padding))
    }

    /// 数字专用样式。默认 20pt，强制等宽数字。
    func dtNumber(_ font: Font = Tokens.Typography.Number.medium,
                  color: Color = Tokens.Palette.textPrimary) -> some View {
        modifier(DTNumber(font: font, color: color))
    }

    func dtPrimaryButton() -> some View {
        modifier(DTPrimaryButton())
    }

    func dtSecondaryButton() -> some View {
        modifier(DTSecondaryButton())
    }

    /// 限制 Dynamic Type 上限，防止大字号撑破布局。
    func dtMaxDynamicType(_ limit: DynamicTypeSize = Tokens.Typography.maxDynamicTypeSize) -> some View {
        dynamicTypeSize(Tokens.Typography.minDynamicTypeSize...limit)
    }
}

// MARK: - 令牌驱动的展示组件

/// 细分割线。
struct DTDivider: View {
    var body: some View {
        Rectangle()
            .fill(Tokens.Palette.separator)
            .frame(height: Tokens.Border.hairline)
    }
}

/// 分区标题。
struct DTSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                Text(title)
                    .font(Tokens.Typography.headline)
                    .foregroundStyle(Tokens.Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Tokens.Typography.caption)
                        .foregroundStyle(Tokens.Palette.textSecondary)
                }
            }
            Spacer(minLength: Tokens.Space.xs)
            if let trailing {
                Text(trailing)
                    .font(Tokens.Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Palette.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 状态胶囊。底色与文字固定使用强调色（保证任何状态下都可读），状态本身由圆点颜色表达。
struct DTStatusChip: View {
    let text: String
    var status: NutrientStatus = .none

    var body: some View {
        HStack(spacing: Tokens.Space.xxs) {
            Circle()
                .fill(status.dtColor)
                .frame(width: Tokens.Layout.statusDotSize, height: Tokens.Layout.statusDotSize)
            Text(text)
        }
        .font(Tokens.Typography.caption)
        .padding(.horizontal, Tokens.Space.xs)
        .padding(.vertical, Tokens.Space.xxs)
        .background(Tokens.Palette.accentSubtle)
        .foregroundStyle(Tokens.Palette.accentText)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
    }
}

/// 仪表盘核心原语：标签 + 数值 + 单位。
struct DTMetric: View {
    let label: String
    let value: Double
    let unit: String
    var status: NutrientStatus = .none
    /// true 时使用强调色，用于「净摄入」这类需要突出的指标。
    var emphasized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            Text(label)
                .font(Tokens.Typography.overline)
                .tracking(Tokens.Typography.overlineTracking)
                .foregroundStyle(Tokens.Palette.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xxs) {
                Text(Self.formatted(value))
                    .dtNumber(
                        emphasized ? Tokens.Typography.Number.medium : Tokens.Typography.Number.small,
                        color: emphasized ? Tokens.Palette.accentText : Tokens.Palette.textPrimary
                    )
                Text(unit)
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dtSurfaceMuted()
    }

    private static func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}

/// 免责声明。所有分析卡片、运动估算旁都必须展示。
struct DTDisclaimer: View {
    static let text = "本 App 数据为估算值，仅供参考，不能替代专业医疗或营养师建议。"

    var body: some View {
        Text(Self.text)
            .font(Tokens.Typography.caption)
            .foregroundStyle(Tokens.Palette.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - 预览

#Preview("主题令牌一览 · 浅色") {
    ThemePreviewContent()
        .preferredColorScheme(.light)
}

#Preview("主题令牌一览 · 深色") {
    ThemePreviewContent()
        .preferredColorScheme(.dark)
}

private struct ThemePreviewContent: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                Text("1,284")
                    .dtNumber(Tokens.Typography.Number.hero)
                Text("净摄入 kcal")
                    .font(Tokens.Typography.overline)
                    .foregroundStyle(Tokens.Palette.textSecondary)

                HStack(spacing: Tokens.Space.xs) {
                    DTMetric(label: "摄入", value: 1824, unit: "kcal")
                    DTMetric(label: "运动", value: 540, unit: "kcal")
                    DTMetric(label: "净摄入", value: 1284, unit: "kcal", emphasized: true)
                }

                DTDivider()

                HStack(spacing: Tokens.Space.xs) {
                    DTStatusChip(text: "充足", status: .sufficient)
                    DTStatusChip(text: "偏低", status: .low)
                    DTStatusChip(text: "偏高", status: .high)
                    DTStatusChip(text: "暂无", status: .none)
                }

                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    DTSectionHeader(title: "今日运动", trailing: "共 540 kcal")
                    Text("跑步 · 30 分钟")
                        .font(Tokens.Typography.body)
                    DTDisclaimer()
                }
                .dtCard()

                Button("分析今天") {}
                    .dtPrimaryButton()
            }
            .padding(Tokens.Space.md)
        }
        .dtScreenBackground()
        .dtTheme(.default)
    }
}
