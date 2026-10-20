//
//  SeedData.swift
//  DietTracker
//
//  首次启动播种：默认 7 个进食时段 + 一份默认用户档案。
//  幂等——已经存在则跳过，重复调用不会产生重复数据。
//

import Foundation
import SwiftData

enum SeedData {

    /// 播种默认时段。已存在同 slotID 的则跳过。
    @MainActor
    static func ensureDefaultMealSlots(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<MealSlot>())) ?? []
        let existingIDs = Set(existing.map { $0.slotID })

        for (index, seed) in MealSlotSeed.defaults.enumerated() {
            guard !existingIDs.contains(seed.slotID) else { continue }
            context.insert(MealSlot(seed: seed, sortOrder: index))
        }
    }

    /// 播种默认档案。已存在档案则不动。
    @MainActor
    static func ensureDefaultProfile(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard existing.isEmpty else { return }
        context.insert(UserProfile())
    }

    /// 一次性完成全部播种并保存。
    @MainActor
    static func bootstrapIfNeeded(in context: ModelContext) {
        ensureDefaultMealSlots(in: context)
        ensureDefaultProfile(in: context)
        try? context.save()
    }

    // MARK: - 预览数据

    /// 仅供 #Preview 与模拟器演示使用，不要打进正式流程。
    @MainActor
    static func makePreviewContext() throws -> ModelContext {
        let container = try AppSchema.makePreviewContainer()
        let context = ModelContext(container)
        bootstrapIfNeeded(in: context)
        return context
    }
}
