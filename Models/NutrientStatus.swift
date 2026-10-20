//
//  NutrientStatus.swift
//  DietTracker
//
//  营养素 / 指标相对推荐摄入量（RDI）的判定状态。
//
//  ⚠️ 设计约束：本状态**只能由 AnalysisEngine 的通道 A 产出**（饮食摄入 vs RDI）。
//     通道 A 的函数签名上拿不到任何运动数据，因此运动量再大也不会把「偏低」改写成「充足」。
//     能量与宏量的判断走通道 B，使用 DailyEnergyBalance，与本枚举无关。
//

import Foundation

enum NutrientStatus: String, Codable, CaseIterable, Sendable {
    /// 70%–130% RDI
    case sufficient
    /// < 70% RDI
    case low
    /// > 130% RDI
    case high
    /// 数据不足（不足 3 天记录），不做判定
    case none

    /// 展示用中文标签
    var displayName: String {
        switch self {
        case .sufficient: return "充足"
        case .low:        return "偏低"
        case .high:       return "偏高"
        case .none:       return "暂无"
        }
    }
}
