//
//  Nutrient.swift
//  DietTracker
//
//  营养素定义与「通道归属」。
//
//  ⚠️ 设计约束（来自 PRD v1.1 双通道判定）：
//     通道 A = 微量营养素（钙 / 铁 / 维C / 纤维）——只看「饮食摄入 vs RDI」，
//              函数签名上拿不到任何运动数据，运动量再大也不能把「偏低」改判为「充足」。
//     通道 B = 能量与宏量（热量 / 蛋白 / 脂肪 / 碳水）——可以读取净能量与 7 天趋势。
//     通道 B 的任何结论都无权修改通道 A 的状态。
//
//  本文件是「哪条营养走哪个通道」的唯一定义处，AnalysisEngine 必须读取 `channel`，
//  不得自行 hardcode 分支，否则双通道隔离形同虚设。
//

import Foundation

// MARK: - 通道

enum AnalysisChannel: String, Codable, CaseIterable, Sendable {
    /// 通道 A：微量营养素。物理隔离运动数据。
    case micronutrient
    /// 通道 B：能量与宏量。可读取净能量与多日趋势。
    case energyMacro

    var displayName: String {
        switch self {
        case .micronutrient: return "微量营养素"
        case .energyMacro:   return "能量与宏量"
        }
    }
}

// MARK: - 营养素

enum Nutrient: String, Codable, CaseIterable, Identifiable, Sendable {

    case energy
    case protein
    case fat
    case carbs
    case calcium
    case iron
    case vitaminC
    case fiber

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .energy:   return "热量"
        case .protein:  return "蛋白质"
        case .fat:      return "脂肪"
        case .carbs:    return "碳水化合物"
        case .calcium:  return "钙"
        case .iron:     return "铁"
        case .vitaminC: return "维生素 C"
        case .fiber:    return "膳食纤维"
        }
    }

    /// 数值单位。UI 显示与建议文案都必须引用这里，不要硬写。
    var unit: String {
        switch self {
        case .energy:                  return "kcal"
        case .calcium, .iron, .vitaminC: return "mg"
        case .protein, .fat, .carbs, .fiber: return "g"
        }
    }

    /// 通道归属。见文件头说明。
    var channel: AnalysisChannel {
        switch self {
        case .energy, .protein, .fat, .carbs:  return .energyMacro
        case .calcium, .iron, .vitaminC, .fiber: return .micronutrient
        }
    }

    /// 展示时保留的小数位。能量与矿物质取整数，宏量保留一位。
    var displayFractionDigits: Int {
        switch self {
        case .energy, .calcium, .iron, .vitaminC: return 0
        case .protein, .fat, .carbs, .fiber:      return 1
        }
    }

    /// 判定顺序（UI 与建议生成的排列依据）。
    static let displayOrder: [Nutrient] = [
        .energy, .protein, .fat, .carbs, .calcium, .iron, .vitaminC, .fiber
    ]

    /// 展示序号。用 `firstIndex` + 兜底而不是强制解包，
    /// 这样将来新增一个营养素却忘了加进 displayOrder 也不会崩。
    var displayIndex: Int {
        Nutrient.displayOrder.firstIndex(of: self) ?? Int.max
    }
}
