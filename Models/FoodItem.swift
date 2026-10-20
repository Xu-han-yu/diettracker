//
//  FoodItem.swift
//  DietTracker
//
//  一条被解析出来的食物及其营养估算结果。
//
//  ⚠️ 可复现性约定：本模型**冗余存储估算快照**——
//     当时的估算克数、营养数值、来源与算法版本全部落库。
//     将来用户改了本地营养表、改了算法版本，历史记录的数字也不会变。
//

import Foundation
import SwiftData

/// 营养数据的来源。**三种来源都只是「估算」**，UI 上必须标注，不能让用户误以为是精确值。
enum NutritionSource: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 本地营养表匹配（离线可用，主路径）
    case localTable
    /// 外部营养 API 增强（可选，Key 为空时不启用）
    case externalAPI
    /// 词典兜底：没匹配到具体食物，用了通用估算值
    case fallback

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .localTable:  return "本地表估算"
        case .externalAPI: return "在线数据估算"
        case .fallback:    return "通用值估算"
        }
    }

    /// 是否需要额外提醒用户「这条可能不准」
    var needsCaution: Bool { self == .fallback }
}

@Model
final class FoodItem {

    var id: UUID = UUID()

    /// 规范化后的食物名（展示用）
    var name: String = ""
    /// 命中的本地营养表条目 ID；nil 表示走了兜底
    var matchedFoodID: String? = nil

    /// 用户原始份量描述，例如「一碗」「两个」「200g」
    var quantityText: String = ""
    /// 估算得到的实际克数
    var grams: Double = 0

    // MARK: 营养快照

    var kcal: Double = 0
    var proteinG: Double = 0
    var fatG: Double = 0
    var carbsG: Double = 0
    var calciumMG: Double = 0
    var ironMG: Double = 0
    var vitaminCMG: Double = 0
    var fiberG: Double = 0

    var sourceRaw: String = NutritionSource.localTable.rawValue
    /// 解析置信度 0...1，越低越应该在 UI 上提示用户确认
    var confidence: Double = 1
    var estimatorVersion: String = EstimatorVersion.food

    var sortOrder: Int = 0
    var createdAt: Date = Date()

    // MARK: 计算属性（不持久化）

    var source: NutritionSource {
        get { NutritionSource(rawValue: sourceRaw) ?? .localTable }
        set { sourceRaw = newValue.rawValue }
    }

    var nutrition: Nutrition {
        Nutrition(kcal: kcal,
                  proteinG: proteinG,
                  fatG: fatG,
                  carbsG: carbsG,
                  calciumMG: calciumMG,
                  ironMG: ironMG,
                  vitaminCMG: vitaminCMG,
                  fiberG: fiberG)
    }

    /// 是否需要用户人工复核（低置信度或走了兜底）
    var needsReview: Bool { confidence < 0.6 || source.needsCaution }

    init() {}

    convenience init(name: String,
                     matchedFoodID: String?,
                     quantityText: String,
                     grams: Double,
                     nutrition: Nutrition,
                     source: NutritionSource,
                     confidence: Double,
                     sortOrder: Int = 0) {
        self.init()
        self.name = name
        self.matchedFoodID = matchedFoodID
        self.quantityText = quantityText
        self.grams = grams
        self.kcal = nutrition.kcal
        self.proteinG = nutrition.proteinG
        self.fatG = nutrition.fatG
        self.carbsG = nutrition.carbsG
        self.calciumMG = nutrition.calciumMG
        self.ironMG = nutrition.ironMG
        self.vitaminCMG = nutrition.vitaminCMG
        self.fiberG = nutrition.fiberG
        self.sourceRaw = source.rawValue
        self.confidence = confidence
        self.sortOrder = sortOrder
        self.estimatorVersion = EstimatorVersion.food
        self.createdAt = Date()
    }
}
