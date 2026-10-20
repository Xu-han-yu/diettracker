//
//  HealthEntries.swift
//  DietTracker
//
//  饮食与运动之外的三类辅助记录：饮水、膳食补充剂、身体数据（体重）。
//  它们在 MVP 中**不参与营养判定**，只作为趋势展示与 MET 计算的体重来源。
//
//  为什么体重要单独存历史：MET 公式需要当时的体重。
//  用户改了设置里的体重，历史运动的消耗数字不该跟着变（可复现性）。
//

import Foundation
import SwiftData

// MARK: - 饮水

@Model
final class WaterEntry {
    var id: UUID = UUID()
    var dayIdentifier: String = ""
    var timestamp: Date = Date()
    /// 毫升
    var amountML: Double = 0
    var note: String? = nil

    init(dayIdentifier: String, timestamp: Date = Date(), amountML: Double, note: String? = nil) {
        self.dayIdentifier = dayIdentifier
        self.timestamp = timestamp
        self.amountML = amountML
        self.note = note
    }

    // SwiftData 取回对象时需要无参 init；自定义 init 会让编译器不再合成，必须显式补上。
    init() {}
}

// MARK: - 膳食补充剂

@Model
final class SupplementEntry {
    var id: UUID = UUID()
    var dayIdentifier: String = ""
    var timestamp: Date = Date()
    var name: String = ""
    /// 剂量描述，例如「1 片」「500mg」。MVP 不解析、不计入营养总量。
    var doseText: String = ""
    var note: String? = nil

    init(dayIdentifier: String,
         timestamp: Date = Date(),
         name: String,
         doseText: String = "",
         note: String? = nil) {
        self.dayIdentifier = dayIdentifier
        self.timestamp = timestamp
        self.name = name
        self.doseText = doseText
        self.note = note
    }

    init() {}
}

// MARK: - 身体数据

@Model
final class BodyMetricEntry {
    var id: UUID = UUID()
    var dayIdentifier: String = ""
    var timestamp: Date = Date()
    /// 体重 kg。0 表示未填写。
    var weightKg: Double = 0
    var note: String? = nil

    init(dayIdentifier: String, timestamp: Date = Date(), weightKg: Double, note: String? = nil) {
        self.dayIdentifier = dayIdentifier
        self.timestamp = timestamp
        self.weightKg = weightKg
        self.note = note
    }

    init() {}
}

// MARK: - 查询辅助

extension BodyMetricEntry {
    /// 取某天之前（含当天）最近一次有效体重；没有则返回 nil（调用方兜底 60kg）。
    static func latestWeight(onOrBefore dayIdentifier: String, from all: [BodyMetricEntry]) -> Double? {
        all.filter { $0.weightKg > 0 && $0.dayIdentifier <= dayIdentifier }
            .sorted { $0.timestamp > $1.timestamp }
            .first?.weightKg
    }
}
