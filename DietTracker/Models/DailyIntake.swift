//
//  DailyIntake.swift
//  DietTracker
//
//  按天聚合的摄入与消耗。AnalysisEngine 与 TrendView 的输入单元。
//  纯值类型，不持久化。
//

import Foundation

/// 某一天的饮食摄入聚合。
struct DailyIntake: Hashable, Sendable {
    var dayIdentifier: String
    var nutrition: Nutrition
    /// 解析出的食物项总数
    var itemCount: Int
    /// 其中命中本地营养表的项数（其余走了兜底）
    var matchedItemCount: Int

    static func empty(dayIdentifier: String) -> DailyIntake {
        DailyIntake(dayIdentifier: dayIdentifier, nutrition: .zero, itemCount: 0, matchedItemCount: 0)
    }

    var hasData: Bool { itemCount > 0 }

    /// 兜底比例，用于提示「今天的记录质量不高」
    var fallbackRatio: Double {
        guard itemCount > 0 else { return 0 }
        return Double(itemCount - matchedItemCount) / Double(itemCount)
    }
}

/// 某一天的完整摘要：摄入 + 运动消耗。趋势分析的基本单元。
struct DailySummary: Hashable, Sendable {
    var dayIdentifier: String
    var intake: Nutrition
    var burnKcal: Double

    var netKcal: Double { intake.kcal - burnKcal }

    static func empty(dayIdentifier: String) -> DailySummary {
        DailySummary(dayIdentifier: dayIdentifier, intake: .zero, burnKcal: 0)
    }

    var hasData: Bool { !intake.isEmpty || burnKcal > 0 }
}

// MARK: - 趋势统计

extension Array where Element == DailySummary {

    /// 只保留有数据的天，按标识符升序。
    var recordedAndSorted: [DailySummary] {
        filter { $0.hasData }.sorted { $0.dayIdentifier < $1.dayIdentifier }
    }

    /// 最近 n 天（按标识符升序）。
    func recent(_ n: Int) -> [DailySummary] {
        guard n > 0 else { return [] }
        return Array(sorted { $0.dayIdentifier > $1.dayIdentifier }.prefix(n))
            .sorted { $0.dayIdentifier < $1.dayIdentifier }
    }

    /// 某营养素在窗口内的日均值。
    func average(of nutrient: Nutrient) -> Double {
        let list = recordedAndSorted
        guard !list.isEmpty else { return 0 }
        return list.reduce(0) { $0 + $1.intake.value(for: nutrient) } / Double(list.count)
    }

    /// 窗口内运动消耗的日均值。
    var averageBurnKcal: Double {
        let list = recordedAndSorted
        guard !list.isEmpty else { return 0 }
        return list.reduce(0) { $0 + $1.burnKcal } / Double(list.count)
    }

    /// 有运动记录的天数。
    var daysWithExercise: Int {
        filter { $0.burnKcal > 0 }.count
    }
}
