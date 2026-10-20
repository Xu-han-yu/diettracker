//
//  EntryWriter.swift
//  DietTracker
//
//  把「用户的一句自然语言」变成落库的一条记录。
//
//  ⚠️ 可复现性：写入时把当时的营养数值 / MET / 体重 / 算法版本**全部快照进模型**。
//     将来用户改了设置里的体重、换了营养表，历史记录的数字不该跟着变。
//

import Foundation
import SwiftData

@MainActor
struct EntryWriter {

    var services: AppServices
    var context: ModelContext

    // MARK: 饮食

    /// 解析并保存一次饮食输入。
    /// - Returns: 新建并已 insert 的 MealEntry；解析不出任何食物时返回 nil。
    @discardableResult
    func saveMeal(dayIdentifier: String,
                  slot: MealSlot,
                  rawText: String) async -> MealEntry? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let result = services.foodParser.parse(trimmed)
        guard !result.isEmpty else { return nil }

        var items: [FoodItem] = []
        for (index, parsed) in result.items.enumerated() {
            let nutrition = await services.nutrition.lookup(parsed: parsed)
            items.append(FoodItem(name: nutrition.name,
                                  matchedFoodID: nutrition.matchedFoodID,
                                  quantityText: parsed.quantityText ?? "",
                                  grams: nutrition.grams,
                                  nutrition: nutrition.nutrition,
                                  source: nutrition.source,
                                  confidence: nutrition.confidence,
                                  sortOrder: index))
        }

        let entry = MealEntry(dayIdentifier: dayIdentifier,
                              slotID: slot.slotID,
                              slotName: slot.name,
                              rawText: trimmed,
                              items: items)
        context.insert(entry)
        try? context.save()
        return entry
    }

    /// 解析食物但**不落库**，用于输入卡片的实时预览。
    func previewFoods(rawText: String) -> FoodParseResult {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        return services.foodParser.parse(trimmed)
    }

    /// 同步拿一个粗略营养值，供预览行显示热量。不联网、不抛错。
    func quickNutrition(for parsed: ParsedFood) -> FoodNutrition {
        services.nutrition.fallback(parsed: parsed)
    }

    // MARK: 运动

    /// 由草稿保存一次运动记录。
    /// - weightKg：估算当时用的体重。历史记录要用当时的体重，不是当前设置里的体重。
    @discardableResult
    func saveExercise(dayIdentifier: String,
                      rawText: String,
                      weightKg: Double,
                      drafts: [ExerciseDraft]) -> ExerciseEntry? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !drafts.isEmpty else { return nil }

        let resolvedWeight = weightKg > 0 ? weightKg : ExerciseFallback.defaultWeightKg

        var items: [ExerciseItem] = []
        for (index, draft) in drafts.enumerated() {
            let parsed = ParsedExercise(name: draft.name,
                                        matchedExerciseID: draft.matchedExerciseID,
                                        minutes: draft.minutes,
                                        intensity: draft.intensity,
                                        confidence: draft.confidence)
            let estimate = services.exerciseCalorie.estimate(parsed: parsed,
                                                             weightKg: resolvedWeight,
                                                             defaultIntensity: draft.intensity)
            items.append(ExerciseItem(name: estimate.name,
                                      matchedExerciseID: estimate.matchedExerciseID,
                                      minutes: estimate.minutes,
                                      intensity: estimate.intensity,
                                      metValue: estimate.metValue,
                                      estimatedKcal: estimate.kcal,
                                      weightKgAtEstimate: estimate.weightKgAtEstimate,
                                      isFallback: estimate.isFallback,
                                      confidence: estimate.confidence,
                                      sortOrder: index))
        }

        let entry = ExerciseEntry(dayIdentifier: dayIdentifier,
                                  rawText: trimmed,
                                  items: items)
        context.insert(entry)
        try? context.save()
        return entry
    }

    /// 解析运动文本，产出可编辑的草稿（时长、强度用户都能改）。
    func previewExercises(rawText: String) -> [ExerciseDraft] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let result = services.exerciseParser.parse(trimmed)
        return result.items.map { parsed in
            ExerciseDraft(name: parsed.name,
                          matchedExerciseID: parsed.matchedExerciseID,
                          minutes: parsed.minutes ?? ExerciseFallback.defaultMinutes,
                          intensity: parsed.intensity ?? .moderate,
                          confidence: parsed.confidence)
        }
    }

    /// 单条草稿的消耗估算，供预览实时刷新。
    func estimate(draft: ExerciseDraft, weightKg: Double) -> ExerciseEstimate {
        let resolved = weightKg > 0 ? weightKg : ExerciseFallback.defaultWeightKg
        let parsed = ParsedExercise(name: draft.name,
                                    matchedExerciseID: draft.matchedExerciseID,
                                    minutes: draft.minutes,
                                    intensity: draft.intensity,
                                    confidence: draft.confidence)
        return services.exerciseCalorie.estimate(parsed: parsed,
                                                 weightKg: resolved,
                                                 defaultIntensity: draft.intensity)
    }
}

// MARK: - 运动草稿

/// 输入卡片里可编辑的一条运动。落库前用户能改时长和强度。
struct ExerciseDraft: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var matchedExerciseID: String?
    var minutes: Double
    var intensity: ExerciseIntensity
    var confidence: Double
}
