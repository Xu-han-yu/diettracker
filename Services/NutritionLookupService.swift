//
//  NutritionLookupService.swift
//  DietTracker
//
//  营养查询协议。
//
//  优先级：本地营养表（离线、主路径） > 外部 API（可选增强） > 通用兜底值。
//  API Key 为空或请求失败时静默回退本地表，**绝不把错误抛给用户**。
//
//  API 配置读取 Info.plist 的 NUTRITION_API_BASE_URL / NUTRITION_API_KEY，
//  两个值都在 project.yml 中以占位符形式声明，留空即关闭增强。
//

import Foundation

/// 单个食物查到的营养结果（已按克数缩放过）。
struct FoodNutrition: Hashable, Sendable {
    var name: String
    var matchedFoodID: String?
    /// 实际参与计算的克数
    var grams: Double
    var nutrition: Nutrition
    var source: NutritionSource
    var confidence: Double
    var estimatorVersion: String

    static func fallback(name: String, grams: Double) -> FoodNutrition {
        FoodNutrition(
            name: name,
            matchedFoodID: nil,
            grams: grams,
            nutrition: Nutrition.zero,
            source: .fallback,
            confidence: 0.3,
            estimatorVersion: EstimatorVersion.food
        )
    }
}

protocol NutritionLookupService {

    /// 查询营养。异步是为了将来接外部 API；本地实现会立即返回。
    /// **本方法不抛错**——任何失败都在内部回退到 fallback，调用方一定拿得到结果。
    func lookup(parsed: ParsedFood) async -> FoodNutrition

    /// 同步兜底路径，永远有结果。用于 UI 需要立刻出数字的场景。
    func fallback(parsed: ParsedFood) -> FoodNutrition

    /// 外部 API 是否已启用（Key 与 BaseURL 都非空）。
    var isExternalAPIEnabled: Bool { get }
}

// MARK: - 配置读取

enum NutritionAPIConfig {
    /// 留空 = 关闭外部增强，纯本地运行。
    static var baseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "NUTRITION_API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "NUTRITION_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isEnabled: Bool { !baseURL.isEmpty && !apiKey.isEmpty }
}
