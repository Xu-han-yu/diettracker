//
//  AnalysisThresholds.swift
//  DietTracker
//
//  判定阈值。默认 70% / 130%，设置页可配置。
//
//  ⚠️ 阈值只作用于「摄入 vs RDI」的比值，不因运动量而变化。
//     运动影响的是「建议文案」与「能量平衡描述」，不改判定状态。
//

import Foundation

struct AnalysisThresholds: Codable, Equatable, Hashable, Sendable {

    /// 低于该比例视为「偏低」，默认 0.70
    var lowRatio: Double = 0.70
    /// 高于该比例视为「偏高」，默认 1.30
    var highRatio: Double = 1.30
    /// 低于该记录天数不做强结论
    var minimumDaysForConclusion: Int = 3
    /// 趋势窗口天数
    var trendWindowDays: Int = 7

    static let `default` = AnalysisThresholds()

    /// 核心判定：实际值 / 目标值 → 状态。
    /// - target <= 0：目标无意义，返回 .none（不是 .low）
    /// - ratio < lowRatio：偏低
    /// - ratio > highRatio：偏高
    /// - 其余：充足
    func status(actual: Double, target: Double) -> NutrientStatus {
        guard target > 0 else { return .none }
        let ratio = actual / target
        if ratio < lowRatio { return .low }
        if ratio > highRatio { return .high }
        return .sufficient
    }

    /// 归一化后的比值（target 为 0 时返回 0，避免除零产生 inf / nan 污染 UI）。
    func ratio(actual: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return actual / target
    }
}
