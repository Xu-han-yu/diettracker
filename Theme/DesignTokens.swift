//
//  DesignTokens.swift
//  DietTracker
//
//  设计令牌唯一定义处。
//  ⚠️ 规则：全项目只有本文件允许出现颜色 / 字号 / 间距 / 圆角的字面量。
//     其他文件一律通过 Tokens.* 或 Theme.swift 提供的 dtXxx 修饰符引用。
//     CI 有脚本（scripts/check-hardcoded-style.sh）强制这条规则。
//

import SwiftUI
import UIKit

// MARK: - 颜色构造（动态适配浅色 / 深色，不依赖 Asset Catalog）

extension UIColor {
    /// 从 0xRRGGBB 构造。仅用于 DesignTokens 内部。
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

extension Color {
    /// 生成一个随系统外观自动切换的 Color。
    /// 用 UIColor 的动态 provider 实现，不需要在 Xcode 里手动建色集。
    static func dt(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traitCollection in
            let hex = traitCollection.userInterfaceStyle == .dark ? dark : light
            return UIColor(hex: hex)
        })
    }
}

extension Font.Weight {
    /// SwiftUI 字重 → UIKit 字重，供 UIFontMetrics 缩放使用。
    ///
    /// 注意：Font.Weight 是**结构体**不是枚举，因此只能对已知取值做等值匹配，
    /// 不能用 `@unknown default`（那只对 enum 合法，会直接编译报错）。
    var uiKitWeight: UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin:       return .thin
        case .light:      return .light
        case .regular:    return .regular
        case .medium:     return .medium
        case .semibold:   return .semibold
        case .bold:       return .bold
        case .heavy:      return .heavy
        case .black:      return .black
        default:          return .regular
        }
    }
}

// MARK: - 令牌命名空间

enum Tokens {

    // MARK: 调色板

    enum Palette {

        // 背景与表面
        /// 页面底色。浅色为近白而非纯白；深色为接近黑而非纯黑（避免 OLED 拖影）。
        static let background          = Color.dt(light: 0xFAFAFC, dark: 0x101114)
        /// 分组底、指标块底
        static let backgroundSecondary = Color.dt(light: 0xF2F3F7, dark: 0x17191D)
        /// 卡片
        static let surface             = Color.dt(light: 0xFFFFFF, dark: 0x1C1F24)
        /// 卡片内嵌块、输入框底
        static let surfaceMuted        = Color.dt(light: 0xF7F8FB, dark: 0x22262C)

        // 文字（石墨黑体系）
        static let textPrimary         = Color.dt(light: 0x1C1E21, dark: 0xEDEEF2)
        static let textSecondary      = Color.dt(light: 0x5A6070, dark: 0xA0A6B4)
        static let textTertiary        = Color.dt(light: 0x8A90A0, dark: 0x6E7482)

        // 边框（细线）
        static let separator           = Color.dt(light: 0xE3E5EC, dark: 0x2A2E36)
        static let separatorStrong     = Color.dt(light: 0xD8DBE3, dark: 0x3A3F49)

        // 强调色（全局唯一）
        /// 用于色块、线条、进度条
        static let accent              = Color.dt(light: 0x2F6FED, dark: 0x6C9BFF)
        /// 用于强调色上的文字（加深一档，保证 WCAG AA 对比度）
        static let accentText          = Color.dt(light: 0x2557C4, dark: 0x93B4FF)
        /// 强调底、状态胶囊
        static let accentSubtle        = Color.dt(light: 0xE8EFFD, dark: 0x1E2A44)

        // 状态色（去饱和，不抢强调色）
        enum Status {
            static let sufficient = Color.dt(light: 0x2F6FED, dark: 0x6C9BFF)
            static let low        = Color.dt(light: 0x6E7B94, dark: 0x8C97AC)
            static let high       = Color.dt(light: 0xA85A4E, dark: 0xC08376)
            static let none       = Color.dt(light: 0xC9CCD6, dark: 0x4A505C)
        }

        // 图表（低饱和 · 细线）
        enum Chart {
            static let intake  = Color.dt(light: 0x2F6FED, dark: 0x6C9BFF)
            static let burn    = Color.dt(light: 0x8FA3C4, dark: 0x7F93B4)
            static let net     = Color.dt(light: 0x5B6B85, dark: 0x8D9BB0)
            static let grid    = Color.dt(light: 0xE3E5EC, dark: 0x2A2E36)
            static let protein = Color.dt(light: 0x4A79C0, dark: 0x7BA0DE)
            static let fat     = Color.dt(light: 0x93A2B8, dark: 0x9AA7BC)
            static let carb    = Color.dt(light: 0xB9C2CF, dark: 0xC3CBD6)
        }
    }

    // MARK: 间距（中等信息密度）

    enum Space {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        /// 卡片内边距默认值
        static let md:  CGFloat = 16
        /// 卡片之间间距
        static let lg:  CGFloat = 20
        /// 分区之间间距
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: 圆角（中等）

    enum Radius {
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let pill: CGFloat = 999
    }

    // MARK: 边框与阴影

    enum Border {
        /// 默认细线宽度
        static let hairline: CGFloat = 0.5
        /// 仅用于焦点 / 选中态
        static let thin: CGFloat = 1
    }

    // MARK: 排版

    enum Typography {

        /// 数字字号。全部配合 .monospacedDigit() 使用，防止数值变化时宽度跳动。
        ///
        /// ⚠️ 必须是计算属性（static var），不能写成 static let：
        ///    UIFontMetrics 需要每次读取当前 traitCollection，缓存成 let 后
        ///    用户在系统设置里改字号时界面不会跟着变。
        enum Number {
            /// 40pt：全局唯一的视觉锚点，只给「今日净摄入」
            static var hero: Font   { Typography.font(size: 40, weight: .semibold, relativeTo: .largeTitle) }
            /// 28pt：摄入 / 消耗 / 各营养素主数值
            static var large: Font  { Typography.font(size: 28, weight: .semibold, relativeTo: .title1) }
            /// 20pt：卡片内次要数值
            static var medium: Font { Typography.font(size: 20, weight: .semibold, relativeTo: .title2) }
            /// 16pt：列表数值
            static var small: Font  { Typography.font(size: 16, weight: .medium,   relativeTo: .body) }
        }

        static var title: Font    { Typography.font(size: 20, weight: .semibold, relativeTo: .title2) }
        static var headline: Font { Typography.font(size: 17, weight: .semibold, relativeTo: .headline) }
        static var body: Font     { Typography.font(size: 15, weight: .regular,  relativeTo: .body) }
        static var subhead: Font  { Typography.font(size: 14, weight: .regular,  relativeTo: .subheadline) }
        static var caption: Font  { Typography.font(size: 13, weight: .regular,  relativeTo: .caption1) }
        static var overline: Font { Typography.font(size: 12, weight: .medium,   relativeTo: .caption2) }

        /// 数据标签（如「蛋白质」「运动消耗」）的额外字距
        static let overlineTracking: CGFloat = 0.5

        /// Dynamic Type 缩放上限，防止最大字号下大数字撑破布局
        static let maxDynamicTypeSize: DynamicTypeSize = .xxxLarge
        static let minDynamicTypeSize: DynamicTypeSize = .xSmall

        // MARK: 动态字体

        /// 用 UIFontMetrics 包装自定义字号，使其随系统字号设置缩放。
        /// 注意：SwiftUI 的 Font.system(size:) 不会自动缩放，必须走这里。
        static func font(size: CGFloat, weight: Font.Weight, relativeTo textStyle: UIFont.TextStyle) -> Font {
            let base = UIFont.systemFont(ofSize: size, weight: weight.uiKitWeight)
            return Font(UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base))
        }
    }

    // MARK: 图表样式

    enum ChartStyle {
        static let lineWidth: CGFloat = 2
        static let pointRadius: CGFloat = 3
        static let symbolSize: CGFloat = 24
        static let gridLineWidth: CGFloat = 0.5
        /// 面积图只允许纯色低透明度填充，禁止渐变
        static let areaFillOpacity: Double = 0.08
        static let spacing: CGFloat = 8
        /// 趋势图默认高度
        static let defaultHeight: CGFloat = 180
    }

    // MARK: 布局

    enum Layout {
        static let screenPadding: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let progressBarHeight: CGFloat = 3
        static let minTouchTarget: CGFloat = 44
        static let statusDotSize: CGFloat = 6
    }
}
