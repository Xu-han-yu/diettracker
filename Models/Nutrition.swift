//
//  Nutrition.swift
//  DietTracker
//
//  一份营养数值。既用于「单个食物项的营养」，也用于「某天摄入总量的聚合」。
//  纯值类型，不持久化（@Model 里以展开字段存储，见 FoodItem）。
//

import Foundation

struct Nutrition: Codable, Equatable, Hashable, Sendable {

    var kcal: Double = 0
    var proteinG: Double = 0
    var fatG: Double = 0
    var carbsG: Double = 0
    var calciumMG: Double = 0
    var ironMG: Double = 0
    var vitaminCMG: Double = 0
    var fiberG: Double = 0

    static let zero = Nutrition()

    init(kcal: Double = 0,
         proteinG: Double = 0,
         fatG: Double = 0,
         carbsG: Double = 0,
         calciumMG: Double = 0,
         ironMG: Double = 0,
         vitaminCMG: Double = 0,
         fiberG: Double = 0) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbsG = carbsG
        self.calciumMG = calciumMG
        self.ironMG = ironMG
        self.vitaminCMG = vitaminCMG
        self.fiberG = fiberG
    }

    /// 按营养素取值。AnalysisEngine 与 UI 统一走这个入口，
    /// 避免各处散落 `switch nutrient` 造成漏项。
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

    mutating func setValue(_ value: Double, for nutrient: Nutrient) {
        switch nutrient {
        case .energy:   kcal = value
        case .protein:  proteinG = value
        case .fat:      fatG = value
        case .carbs:    carbsG = value
        case .calcium:  calciumMG = value
        case .iron:     ironMG = value
        case .vitaminC: vitaminCMG = value
        case .fiber:    fiberG = value
        }
    }

    /// 按份量系数缩放（本地营养表按每 100g 存储，实际克数 / 100 即系数）。
    func scaled(by factor: Double) -> Nutrition {
        Nutrition(kcal: kcal * factor,
                  proteinG: proteinG * factor,
                  fatG: fatG * factor,
                  carbsG: carbsG * factor,
                  calciumMG: calciumMG * factor,
                  ironMG: ironMG * factor,
                  vitaminCMG: vitaminCMG * factor,
                  fiberG: fiberG * factor)
    }

    mutating func add(_ other: Nutrition) {
        kcal += other.kcal
        proteinG += other.proteinG
        fatG += other.fatG
        carbsG += other.carbsG
        calciumMG += other.calciumMG
        ironMG += other.ironMG
        vitaminCMG += other.vitaminCMG
        fiberG += other.fiberG
    }

    static func + (lhs: Nutrition, rhs: Nutrition) -> Nutrition {
        var r = lhs
        r.add(rhs)
        return r
    }

    /// 一天是否完全没有记录。用于「不足 3 天不做强结论」前的空数据过滤。
    var isEmpty: Bool {
        kcal == 0 && proteinG == 0 && fatG == 0 && carbsG == 0
            && calciumMG == 0 && ironMG == 0 && vitaminCMG == 0 && fiberG == 0
    }
}
