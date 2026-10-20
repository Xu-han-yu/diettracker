//
//  ExerciseEntry.swift
//  DietTracker
//
//  一条运动记录：用户的一次自然语言输入，解析出 1..n 个 ExerciseItem。
//
//  ⚠️ 这里只统计「刻意锻炼」。日常走动已经算在活动系数里了，不要重复计。
//

import Foundation
import SwiftData

@Model
final class ExerciseEntry {

    var id: UUID = UUID()
    var dayIdentifier: String = ""
    var timestamp: Date = Date()

    /// 用户原始输入，永远保留
    var rawText: String = ""
    var note: String? = nil

    @Relationship(deleteRule: .cascade) var items: [ExerciseItem] = []

    init() {}

    convenience init(dayIdentifier: String,
                     timestamp: Date = Date(),
                     rawText: String,
                     note: String? = nil,
                     items: [ExerciseItem] = []) {
        self.init()
        self.dayIdentifier = dayIdentifier
        self.timestamp = timestamp
        self.rawText = rawText
        self.note = note
        self.items = items
    }

    // MARK: 聚合（不持久化）

    var totalKcal: Double { items.reduce(0) { $0 + $1.estimatedKcal } }

    var totalMinutes: Double { items.reduce(0) { $0 + $1.minutes } }

    var summaryText: String {
        let names = items.map { $0.name }.filter { !$0.isEmpty }
        guard !names.isEmpty else { return rawText }
        let shown = names.prefix(3).joined(separator: " · ")
        return names.count > 3 ? "\(shown) 等\(names.count)项" : shown
    }

    var needsReview: Bool { items.contains { $0.needsReview } }
}
