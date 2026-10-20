//
//  ExerciseParsingService.swift
//  DietTracker
//
//  运动自然语言解析协议。
//
//  支持形如「跑步 30 分钟」「快走 1 小时」「力量训练 40 分钟」「游泳 45 分钟」的输入。
//  解析运动类型 / 时长 / 强度；强度默认中等，用户可手动改。
//
//  MVP 只做本地实现（运动词典 + 规则/正则 + 时长识别），不依赖任何运动 API、
//  不接入 HealthKit / GPS / 心率 / Apple Watch。
//

import Foundation

/// 解析出的单个运动（尚未算消耗）。
struct ParsedExercise: Hashable, Sendable {
    var name: String
    /// 命中的本地 MET 表条目 ID；nil 表示没匹配到
    var matchedExerciseID: String?
    /// 时长（分钟）；nil 表示没识别出来，调用方用默认时长兜底
    var minutes: Double?
    /// 强度；nil 表示没识别出来，默认中等
    var intensity: ExerciseIntensity?
    var confidence: Double

    var hasDuration: Bool { (minutes ?? 0) > 0 }
}

/// 一次输入的完整解析结果。
struct ExerciseParseResult: Hashable, Sendable {
    var rawText: String
    var items: [ParsedExercise]
    var unmatchedSegments: [String]

    var isEmpty: Bool { items.isEmpty }
    static let empty = ExerciseParseResult(rawText: "", items: [], unmatchedSegments: [])
}

protocol ExerciseParsingService {
    /// 纯同步、纯本地，可在飞行模式下调用。
    func parse(_ text: String) -> ExerciseParseResult
}
