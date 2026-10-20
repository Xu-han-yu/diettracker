//
//  UserProfile.swift
//  DietTracker
//
//  用户档案：性别 / 年龄 / 身高 / 体重 / 活动水平 / 目标 + 可配置判定阈值。
//
//  为什么要拆出 UserProfileSnapshot：
//     @Model 是引用类型且不具备 Sendable 语义，直接把它传给 AnalysisEngine
//     会污染分析层的纯度（无法单测、无法跨线程）。
//     分析引擎只吃值类型快照，持久化层负责转换。
//

import Foundation
import SwiftData

// MARK: - 枚举

enum Sex: String, Codable, CaseIterable, Identifiable, Sendable {
    case male
    case female
    case unspecified

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male:        return "男"
        case .female:      return "女"
        case .unspecified: return "未填写"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case sedentary
    case light
    case moderate
    case active

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sedentary: return "久坐"
        case .light:     return "轻度活动"
        case .moderate:  return "中度活动"
        case .active:    return "高度活动"
        }
    }

    /// 活动系数。**定义为「除刻意锻炼之外的日常活动量」**。
    /// 详见 `guidance` —— 这条文案是解决「双重计算」风险的第一道防线。
    var coefficient: Double {
        switch self {
        case .sedentary: return 1.20
        case .light:     return 1.375
        case .moderate:  return 1.55
        case .active:    return 1.725
        }
    }

    /// 设置页必须展示的说明文字。不要删改，它直接决定用户会不会把锻炼算两遍。
    var guidance: String {
        "请按你的工作和日常走动来选，不要把跑步、健身这类刻意锻炼算进去 —— 锻炼请在今日页单独记录，否则消耗会被计算两次。"
    }

    /// 与「有运动记录」组合时的双重计算风险等级。
    var doubleCountRisk: Double {
        switch self {
        case .sedentary: return 0.0
        case .light:     return 0.2
        case .moderate:  return 0.6
        case .active:    return 1.0
        }
    }
}

enum Goal: String, Codable, CaseIterable, Identifiable, Sendable {
    case maintain
    case cut
    case bulk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .maintain: return "维持"
        case .cut:      return "减脂"
        case .bulk:     return "增肌"
        }
    }

    var energyFactor: Double {
        switch self {
        case .maintain: return 1.00
        case .cut:      return 0.80
        case .bulk:     return 1.10
        }
    }

    /// 每公斤体重目标蛋白（g）
    var proteinPerKg: Double {
        switch self {
        case .maintain: return 1.2
        case .cut:      return 1.6
        case .bulk:     return 1.8
        }
    }
}

// MARK: - 值类型快照

struct UserProfileSnapshot: Codable, Equatable, Hashable, Sendable {
    var sex: Sex
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var activityLevel: ActivityLevel
    var goal: Goal

    static let placeholder = UserProfileSnapshot(
        sex: .unspecified,
        age: 30,
        heightCm: 170,
        weightKg: 60,
        activityLevel: .light,
        goal: .maintain
    )

    var rdi: NutritionProfile { NutritionProfile.compute(from: self) }
}

// MARK: - SwiftData 模型

@Model
final class UserProfile {

    var sexRaw: String = Sex.unspecified.rawValue
    var age: Int = 30
    var heightCm: Double = 170
    /// 体重。**MET 公式与蛋白质目标都依赖它**，设置页为必填项。
    var weightKg: Double = 60
    var activityLevelRaw: String = ActivityLevel.light.rawValue
    var goalRaw: String = Goal.maintain.rawValue

    /// 判定阈值（可配置，默认 70% / 130%）
    var lowRatioThreshold: Double = 0.70
    var highRatioThreshold: Double = 1.30
    /// 少于该天数不做强结论（避免刚上手就被输出「严重缺钙」这类应激判断）
    var minimumDaysForConclusion: Int = 3
    /// 趋势窗口天数
    var trendWindowDays: Int = 7

    var updatedAt: Date = Date()

    // MARK: 计算属性（不持久化）

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .unspecified }
        set { sexRaw = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .light }
        set { activityLevelRaw = newValue.rawValue }
    }

    var goal: Goal {
        get { Goal(rawValue: goalRaw) ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }

    /// 体重是否已由用户设置。设置页据此提示，未设置时按 60kg 兜底并明确标注。
    var isWeightConfigured: Bool { weightKg > 0 }

    /// MET / 蛋白质计算实际使用的体重。未设置时兜底 60kg。
    var effectiveWeightKg: Double { weightKg > 0 ? weightKg : 60 }

    var snapshot: UserProfileSnapshot {
        UserProfileSnapshot(sex: sex,
                           age: age,
                           heightCm: heightCm,
                           weightKg: effectiveWeightKg,
                           activityLevel: activityLevel,
                           goal: goal)
    }

    var thresholds: AnalysisThresholds {
        AnalysisThresholds(lowRatio: lowRatioThreshold,
                           highRatio: highRatioThreshold,
                           minimumDaysForConclusion: minimumDaysForConclusion,
                           trendWindowDays: trendWindowDays)
    }

    var rdi: NutritionProfile { NutritionProfile.compute(from: snapshot) }

    init() {}
}
