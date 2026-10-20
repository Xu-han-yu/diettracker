//
//  MealEntry.swift
//  DietTracker
//
//  一条饮食记录：用户的一次自然语言输入，解析出 1..n 个 FoodItem。
//
//  存储约定：
//   - `dayIdentifier` 用于按日查询（yyyy-MM-dd，见 DayIdentifier）
//   - `timestamp` 保留真实时间，用于历史页排序与「随手记」时间轴
//   - `slotID` / `slotName` 冗余快照，时段改名不影响历史
//

import Foundation
import SwiftData

@Model
final class MealEntry {

    var id: UUID = UUID()
    var dayIdentifier: String = ""
    var timestamp: Date = Date()

    var slotID: String = ""
    var slotName: String = ""

    /// 用户原始输入，永远保留，便于事后修正与纠错分析
    var rawText: String = ""
    var note: String? = nil

    @Relationship(deleteRule: .cascade) var items: [FoodItem] = []

    init() {}

    convenience init(dayIdentifier: String,
                     timestamp: Date = Date(),
                     slotID: String,
                     slotName: String,
                     rawText: String,
                     note: String? = nil,
                     items: [FoodItem] = []) {
        self.init()
        self.dayIdentifier = dayIdentifier
        self.timestamp = timestamp
        self.slotID = slotID
        self.slotName = slotName
        self.rawText = rawText
        self.note = note
        self.items = items
    }

    // MARK: 聚合（不持久化）

    var nutrition: Nutrition {
        items.reduce(into: Nutrition.zero) { $0.add($1.nutrition) }
    }

    var totalKcal: Double { items.reduce(0) { $0 + $1.kcal } }

    /// 列表副标题，例如「米饭 · 红烧肉 · 青菜」
    var summaryText: String {
        let names = items.map { $0.name }.filter { !$0.isEmpty }
        guard !names.isEmpty else { return rawText }
        let shown = names.prefix(3).joined(separator: " · ")
        return names.count > 3 ? "\(shown) 等\(names.count)项" : shown
    }

    var needsReview: Bool { items.contains { $0.needsReview } }
}
