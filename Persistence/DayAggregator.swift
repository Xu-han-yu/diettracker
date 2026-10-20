//
//  DayAggregator.swift
//  DietTracker
//
//  按天聚合：把 SwiftData 里的 MealEntry / ExerciseEntry 压成
//  AnalysisEngine 与趋势图需要的纯值类型。
//
//  纯函数，不碰 ModelContext，方便单测。
//

import Foundation

enum DayAggregator {

    /// 某一天的饮食摄入聚合。
    static func intake(dayIdentifier: String, from meals: [MealEntry]) -> DailyIntake {
        var nutrition = Nutrition.zero
        var itemCount = 0
        var matchedItemCount = 0

        for meal in meals where meal.dayIdentifier == dayIdentifier {
            for item in meal.items {
                nutrition.add(item.nutrition)
                itemCount += 1
                if item.source != .fallback { matchedItemCount += 1 }
            }
        }

        return DailyIntake(dayIdentifier: dayIdentifier,
                           nutrition: nutrition,
                           itemCount: itemCount,
                           matchedItemCount: matchedItemCount)
    }

    /// 某一天的运动消耗合计。
    static func burnKcal(dayIdentifier: String, from exercises: [ExerciseEntry]) -> Double {
        exercises
            .filter { $0.dayIdentifier == dayIdentifier }
            .reduce(0) { $0 + $1.totalKcal }
    }

    /// 某一天的运动时长合计（分钟）。
    static func exerciseMinutes(dayIdentifier: String, from exercises: [ExerciseEntry]) -> Double {
        exercises
            .filter { $0.dayIdentifier == dayIdentifier }
            .reduce(0) { $0 + $1.totalMinutes }
    }

    /// 一批天的完整摘要，供 AnalysisContext.history 与趋势图使用。
    static func summaries(days: [String],
                          meals: [MealEntry],
                          exercises: [ExerciseEntry]) -> [DailySummary] {
        days.map { day in
            DailySummary(dayIdentifier: day,
                         intake: intake(dayIdentifier: day, from: meals).nutrition,
                         burnKcal: burnKcal(dayIdentifier: day, from: exercises))
        }
    }

    /// 有记录（饮食或运动任一）的天，按标识符升序。
    static func recordedDays(from summaries: [DailySummary]) -> [DailySummary] {
        summaries.filter { $0.hasData }
    }
}
