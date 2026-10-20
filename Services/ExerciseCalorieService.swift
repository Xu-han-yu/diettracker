//
//  ExerciseCalorieService.swift
//  DietTracker
//
//  运动消耗估算协议（MET 公式）。
//
//     消耗 kcal = MET × 体重(kg) × 小时数
//
//  解析失败时回退到「中等强度一般运动」的默认 MET（5.0），并明确标注 isFallback = true。
//  MVP 不依赖任何外部运动 API、不接 HealthKit。
//

import Foundation

/// 兜底常量。**所有实现都必须用这一组值**，保证同一份输入在任何实现下算出同一个数（可复现）。
enum ExerciseFallback {
    /// 中等强度一般运动的 MET 值
    static let met: Double = 5.0
    static let name = "一般运动"
    /// 没识别出时长时的默认时长（分钟）
    static let defaultMinutes: Double = 30
    /// 时长上限：超过 6 小时多半是误输入，夹一下防止出现离谱数字
    static let maxMinutes: Double = 360
    /// 设置页体重未填时用于 MET 计算的兜底体重（kg）
    static let defaultWeightKg: Double = 60
}

/// MET 公式。
enum METFormula {
    /// kcal = MET × 体重kg × 小时数
    static func kcal(met: Double, weightKg: Double, minutes: Double) -> Double {
        guard met > 0, weightKg > 0, minutes > 0 else { return 0 }
        let hours = minutes / 60.0
        let value = met * weightKg * hours
        return (value * 10).rounded() / 10   // 保留一位小数，便于展示与对账
    }
}

/// 消耗估算结果。
struct ExerciseEstimate: Hashable, Sendable {
    var name: String
    var matchedExerciseID: String?
    var minutes: Double
    var intensity: ExerciseIntensity
    var metValue: Double
    var kcal: Double
    /// true = 没匹配到具体运动，用了默认 MET
    var isFallback: Bool
    /// 估算当时用的体重。必须冗余存下来：用户改了设置里的体重后，
    /// 历史记录里的消耗数字不能跟着变（可复现性）。
    var weightKgAtEstimate: Double
    var confidence: Double
    var estimatorVersion: String

    /// UI 上必须展示的估算标注
    var cautionText: String? {
        isFallback ? "未匹配到具体运动，按「中等强度一般运动」估算" : nil
    }

    /// 一句话解释这个数是怎么来的，用于 UI 的「为什么是这个数」提示。
    var formulaText: String {
        "MET \(metValue.formatted(.number.precision(.fractionLength(1)))) × "
        + "\(weightKgAtEstimate.formatted(.number.precision(.fractionLength(1))))kg × "
        + "\((minutes / 60).formatted(.number.precision(.fractionLength(2))))h"
    }
}

protocol ExerciseCalorieService {

    /// 由解析结果算消耗。
    /// - weightKg：估算当时用的体重（历史记录要用当时的体重，不是当前设置里的体重）
    /// - defaultIntensity：解析不出强度时的默认档，通常传 .moderate
    func estimate(parsed: ParsedExercise,
                  weightKg: Double,
                  defaultIntensity: ExerciseIntensity) -> ExerciseEstimate

    /// 直接查 MET；命中不到返回 nil（由 estimate 决定兜底策略）。
    func metValue(exerciseID: String, intensity: ExerciseIntensity) -> Double?
}
