//
//  METExerciseCalorieService.swift
//  DietTracker
//
//  运动消耗估算：kcal = MET × 体重kg × 小时数
//
//  硬约束：
//   · 查不到运动时回退到 `ExerciseFallback.met`（中等强度一般运动），并**必须**标记 isFallback。
//   · 结果里冗余存 `metValue` / `weightKgAtEstimate` / `estimatorVersion`，
//     这样用户改了体重后历史记录的数字不会跟着变（可复现性验收项）。
//

import Foundation

struct METExerciseCalorieService: ExerciseCalorieService {

    func estimate(parsed: ParsedExercise,
                  weightKg: Double,
                  defaultIntensity: ExerciseIntensity) -> ExerciseEstimate {

        let weight = weightKg > 0 ? weightKg : ExerciseFallback.defaultWeightKg
        // 兜底并限幅：时长不可能为负，超过上限多半是误输入
        let minutes = min(max(parsed.minutes ?? ExerciseFallback.defaultMinutes, 0),
                          ExerciseFallback.maxMinutes)

        let intensity = parsed.intensity ?? defaultIntensity

        if let id = parsed.matchedExerciseID,
           let met = metValue(exerciseID: id, intensity: intensity) {
            let kcal = METFormula.kcal(met: met, weightKg: weight, minutes: minutes)
            return ExerciseEstimate(
                name: parsed.name,
                matchedExerciseID: id,
                minutes: minutes,
                intensity: intensity,
                metValue: met,
                kcal: kcal,
                isFallback: false,
                weightKgAtEstimate: weight,
                estimatorVersion: EstimatorVersion.exerciseMET,
                confidence: parsed.confidence
            )
        }

        // 未命中：回退到「中等强度一般运动」，明确标注为估算
        let met = ExerciseFallback.met
        let kcal = METFormula.kcal(met: met, weightKg: weight, minutes: minutes)
        let name = parsed.name.isEmpty ? ExerciseFallback.name : parsed.name

        return ExerciseEstimate(
            name: name,
            matchedExerciseID: nil,
            minutes: minutes,
            intensity: intensity,
            metValue: met,
            kcal: kcal,
            isFallback: true,
            weightKgAtEstimate: weight,
            estimatorVersion: EstimatorVersion.exerciseMET,
            confidence: min(parsed.confidence, 0.35)
        )
    }

    func metValue(exerciseID: String, intensity: ExerciseIntensity) -> Double? {
        ExerciseDatabase.entry(id: exerciseID)?.met(for: intensity)
    }
}
