//
//  DailyEnergyBalance.swift
//  DietTracker
//
//  净能量平衡 = 饮食摄入 − 运动消耗。
//
//  ⚠️ 三条硬约束（PRD v1.1）：
//   1. 这是**描述性指标**，不是判定性指标。判定主线恒为「摄入 vs RDI」。
//   2. `netKcal` 只影响能量与宏量的建议（通道 B），
//      永远不参与微量营养素（通道 A）的状态判定。
//   3. 运动消耗**不回加**到 RDI —— 否则就是在鼓励「跑了就能吃回去」。
//
//  本结构体不持久化，由 AnalysisEngine 每次实时计算。
//

import Foundation

enum EnergyBalanceStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case largeDeficit
    case moderateDeficit
    case balanced
    case moderateSurplus
    case largeSurplus
    /// 数据不足（无 RDI 或无记录）
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .largeDeficit:    return "缺口偏大"
        case .moderateDeficit: return "适度缺口"
        case .balanced:        return "基本持平"
        case .moderateSurplus: return "略有盈余"
        case .largeSurplus:    return "盈余偏多"
        case .unknown:         return "暂无数据"
        }
    }

    /// 对应的通用判定状态，供 UI 取色（DTStatusChip 等）。
    /// 注意：这只是「展示色」，不代表营养素判定结论。
    var nutrientStatus: NutrientStatus {
        switch self {
        case .largeDeficit:    return .low
        case .moderateDeficit: return .sufficient
        case .balanced:        return .sufficient
        case .moderateSurplus: return .sufficient
        case .largeSurplus:    return .high
        case .unknown:         return .none
        }
    }
}

struct DailyEnergyBalance: Codable, Equatable, Hashable, Sendable {

    /// 当日饮食摄入
    var intakeKcal: Double = 0
    /// 当日刻意锻炼消耗（MET 估算）
    var burnKcal: Double = 0
    /// 当日推荐摄入量（不含运动回加）
    var rdiKcal: Double = 0
    var status: EnergyBalanceStatus = .unknown
    /// 面向用户的客观说明，不做价值判断
    var note: String = ""

    /// 净摄入 = 摄入 − 消耗
    var netKcal: Double { intakeKcal - burnKcal }

    /// 净摄入相对 RDI 的比例
    var netToRDIRatio: Double {
        guard rdiKcal > 0 else { return 0 }
        return netKcal / rdiKcal
    }

    /// 摄入相对 RDI 的比例（判定主线用的就是这个）
    var intakeToRDIRatio: Double {
        guard rdiKcal > 0 else { return 0 }
        return intakeKcal / rdiKcal
    }

    static let unknownValue = DailyEnergyBalance()

    /// 唯一构造入口。阈值固定：0.7 / 0.9 / 1.1 / 1.3。
    static func make(intakeKcal: Double, burnKcal: Double, rdiKcal: Double) -> DailyEnergyBalance {
        guard rdiKcal > 0 else {
            return DailyEnergyBalance(intakeKcal: intakeKcal,
                                      burnKcal: burnKcal,
                                      rdiKcal: 0,
                                      status: .unknown,
                                      note: "尚未设置个人档案，无法计算能量平衡。")
        }

        let ratio = (intakeKcal - burnKcal) / rdiKcal
        let status: EnergyBalanceStatus
        let note: String

        // 用 if-else 而非浮点区间 switch：区间 switch 在 Double 上依赖 ~= 重载，
        // 可读性也差，这里显式写阈值更便于与设置页对齐。
        if ratio < 0.70 {
            status = .largeDeficit
            note = "净摄入明显低于推荐量，若连续多日如此需留意恢复与进食是否跟上。"
        } else if ratio < 0.90 {
            status = .moderateDeficit
            note = "净摄入略低于推荐量，属于常见的减脂区间。"
        } else if ratio <= 1.10 {
            status = .balanced
            note = "净摄入与推荐量基本持平。"
        } else if ratio <= 1.30 {
            status = .moderateSurplus
            note = "净摄入略高于推荐量。"
        } else {
            status = .largeSurplus
            note = "净摄入明显高于推荐量。"
        }

        return DailyEnergyBalance(intakeKcal: intakeKcal,
                                  burnKcal: burnKcal,
                                  rdiKcal: rdiKcal,
                                  status: status,
                                  note: note)
    }
}
