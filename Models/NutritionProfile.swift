//
//  NutritionProfile.swift
//  DietTracker
//
//  每日推荐摄入量（RDI）。
//
//  ⚠️ 硬约束：RDI **不含运动回加**。
//     活动系数已经隐含了日常活动量；如果在 App 里再记录跑步并把消耗加回 RDI，
//     就会诱导「跑了 5 公里所以能吃回去」的补偿性进食，与减脂目标直接相悖。
//     运动消耗只出现在 DailyEnergyBalance 里，永远不进入 RDI。
//
//  公式（简化版，设置页对用户可见）：
//     BMR   = Mifflin-St Jeor
//     TDEE  = BMR × 活动系数
//     kcal  = TDEE × 目标系数（维持 1.00 / 减脂 0.80 / 增肌 1.10）
//     蛋白质 = 体重kg × 目标蛋白系数（维持 1.2 / 减脂 1.6 / 增肌 1.8）
//     脂肪   = kcal × 25% ÷ 9
//     碳水   = 剩余热量 ÷ 4
//     微量   = 中国居民 DRIs 简化值
//

import Foundation

struct NutritionProfile: Codable, Equatable, Hashable, Sendable {

    var kcal: Double = 2000
    var proteinG: Double = 60
    var fatG: Double = 55
    var carbsG: Double = 275
    var calciumMG: Double = 800
    var ironMG: Double = 12
    var vitaminCMG: Double = 100
    var fiberG: Double = 25

    /// 计算所用版本号，写入历史快照用于可复现性。
    var estimatorVersion: String = EstimatorVersion.rdi

    func value(for nutrient: Nutrient) -> Double {
        switch nutrient {
        case .energy:   return kcal
        case .protein:  return proteinG
        case .fat:      return fatG
        case .carbs:    return carbsG
        case .calcium:  return calciumMG
        case .iron:     return ironMG
        case .vitaminC: return vitaminCMG
        case .fiber:    return fiberG
        }
    }

    var asNutrition: Nutrition {
        Nutrition(kcal: kcal,
                  proteinG: proteinG,
                  fatG: fatG,
                  carbsG: carbsG,
                  calciumMG: calciumMG,
                  ironMG: ironMG,
                  vitaminCMG: vitaminCMG,
                  fiberG: fiberG)
    }
}

// MARK: - 计算

extension NutritionProfile {

    /// 由用户档案计算 RDI。纯函数，无副作用，便于单测。
    static func compute(from p: UserProfileSnapshot) -> NutritionProfile {
        let weight = max(p.weightKg, 20)
        let height = max(p.heightCm, 100)
        let age = min(max(p.age, 12), 100)

        // 1) Mifflin-St Jeor 基础代谢
        let base = 10 * weight + 6.25 * height - 5 * Double(age)
        let bmr: Double
        switch p.sex {
        case .male:        bmr = base + 5
        case .female:      bmr = base - 161
        case .unspecified: bmr = base - 78   // 取男女常数中点，避免极端偏差
        }

        // 2) 活动系数（不含刻意锻炼，见 UserProfile.ActivityLevel 说明）
        let tdee = bmr * p.activityLevel.coefficient

        // 3) 目标调整
        var kcal = tdee * p.goal.energyFactor

        // 4) 安全下限：任何目标都不低于同性别的保守底线
        let floorKcal: Double = (p.sex == .female) ? 1200 : 1500
        kcal = max(kcal, floorKcal)

        // 5) 宏量分配
        let proteinG = weight * p.goal.proteinPerKg
        let fatG = kcal * 0.25 / 9
        let carbsKcal = max(kcal - proteinG * 4 - fatG * 9, 0)
        let carbsG = carbsKcal / 4

        // 6) 微量：中国居民 DRIs 简化值
        let ironMG: Double = (p.sex == .female) ? 18 : 12

        return NutritionProfile(kcal: kcal,
                                proteinG: proteinG,
                                fatG: fatG,
                                carbsG: carbsG,
                                calciumMG: 800,
                                ironMG: ironMG,
                                vitaminCMG: 100,
                                fiberG: 25,
                                estimatorVersion: EstimatorVersion.rdi)
    }
}
