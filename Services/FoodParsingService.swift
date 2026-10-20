//
//  FoodParsingService.swift
//  DietTracker
//
//  食物自然语言解析协议。
//
//  MVP 只提供本地实现（词典 + 规则/正则 + 份量估算），**不依赖大模型、不联网**。
//  第 4 步给出 `LocalFoodParsingService`。
//
//  设计原则：解析结果永远是「可修正的猜测」，不是最终答案。
//  只要 confidence 低或走了兜底，UI 必须让用户能改。
//

import Foundation

/// 解析出的单个食物（尚未查营养，只有名字与份量）。
struct ParsedFood: Hashable, Sendable {
    /// 规范化后的食物名
    var name: String
    /// 命中的本地词典条目 ID；nil 表示没匹配到
    var matchedFoodID: String?
    /// 用户原始份量描述，例如「一碗」「两个」「200g」
    var quantityText: String?
    /// 估算克数；nil 表示没识别出份量，由调用方用默认份量兜底
    var grams: Double?
    /// 置信度 0...1
    var confidence: Double

    /// 是否明确识别出了份量
    var hasQuantity: Bool { grams != nil && (grams ?? 0) > 0 }
}

/// 一次输入的完整解析结果。
struct FoodParseResult: Hashable, Sendable {
    var rawText: String
    var items: [ParsedFood]
    /// 没能识别出食物的文本片段，UI 需要提示用户
    var unmatchedSegments: [String]

    var isEmpty: Bool { items.isEmpty }
    static let empty = FoodParseResult(rawText: "", items: [], unmatchedSegments: [])
}

protocol FoodParsingService {
    /// 纯同步、纯本地。不做网络请求，可在飞行模式下调用。
    func parse(_ text: String) -> FoodParseResult
}
