//
//  LocalNutritionLookupService.swift
//  DietTracker
//
//  营养查询：本地表为主，外部 API 为可选增强，失败静默兜底。
//
//  优先级：
//    1. 命中本地食物表 → 用本地值（离线、可复现，优先于 API）
//    2. 没命中且 API 已配置 → 试一次外部查询
//    3. 还没结果 → 通用兜底值，source = .fallback，confidence 0.3
//
//  ⚠️ 本机不抛错。任何失败都在内部消化，调用方一定拿得到 FoodNutrition。
//    这就是为什么 `lookup` 的返回类型不是 Optional 也不 throws。
//

import Foundation

struct LocalNutritionLookupService: NutritionLookupService {

    private let client = ExternalNutritionClient()

    var isExternalAPIEnabled: Bool { NutritionAPIConfig.isEnabled }

    func lookup(parsed: ParsedFood) async -> FoodNutrition {
        let grams = grams(for: parsed)

        // 1) 本地表
        if let id = parsed.matchedFoodID, let entry = FoodDatabase.entry(id: id) {
            return FoodNutrition(
                name: entry.name,
                matchedFoodID: id,
                grams: grams,
                nutrition: entry.per100g.scaled(by: grams / 100.0),
                source: .localTable,
                confidence: parsed.confidence,
                estimatorVersion: EstimatorVersion.food
            )
        }

        // 2) 外部 API（未配置 Key 时这一步不会执行）
        if NutritionAPIConfig.isEnabled, let remote = await client.fetch(name: parsed.name) {
            return FoodNutrition(
                name: parsed.name,
                matchedFoodID: nil,
                grams: grams,
                nutrition: remote.scaled(by: grams / 100.0),
                source: .externalAPI,
                confidence: 0.70,
                estimatorVersion: EstimatorVersion.food
            )
        }

        // 3) 兜底
        return fallback(parsed: parsed)
    }

    func fallback(parsed: ParsedFood) -> FoodNutrition {
        let grams = grams(for: parsed)
        return FoodNutrition(
            name: parsed.name.isEmpty ? "未识别食物" : parsed.name,
            matchedFoodID: nil,
            grams: grams,
            nutrition: FoodDatabase.unknownPer100g.scaled(by: grams / 100.0),
            source: .fallback,
            confidence: 0.30,
            estimatorVersion: EstimatorVersion.food
        )
    }

    private func grams(for parsed: ParsedFood) -> Double {
        let g = parsed.grams ?? FoodDatabase.unknownDefaultGrams
        return min(max(g, 0), 5000)   // 限幅，防误输入产生离谱数值
    }
}

// MARK: - 外部 API 占位实现

/// 外部营养 API 客户端。
///
/// ⚠️ 这是一个**占位实现**：Info.plist 里的 `NUTRITION_API_BASE_URL` / `NUTRITION_API_KEY`
///    默认留空，因此 `isEnabled == false`，本客户端**永远不会发起请求**。
///
/// 接入真实服务时需要改两处：
///   1. `requestURL(name:)` 适配该服务的路径与参数
///   2. `ExternalNutritionResponse` 适配该服务返回的字段
/// 其余「失败即静默回退」的逻辑不用动。
struct ExternalNutritionClient: Sendable {

    /// 查询失败返回 nil，调用方会自行回退到兜底值。**不抛错。**
    func fetch(name: String) async -> Nutrition? {
        guard NutritionAPIConfig.isEnabled else { return nil }
        guard let url = requestURL(name: name) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return nil }
            let decoded = try JSONDecoder().decode(ExternalNutritionResponse.self, from: data)
            return decoded.firstNutrition
        } catch {
            // 网络失败 / 格式不符 / 超时：一律静默回退
            return nil
        }
    }

    /// baseURL 需要是完整 URL（含 scheme 与 path），例如 `https://api.example.com/v1/food`。
    private func requestURL(name: String) -> URL? {
        guard var components = URLComponents(string: NutritionAPIConfig.baseURL) else { return nil }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "name", value: name))
        items.append(URLQueryItem(name: "apiKey", value: NutritionAPIConfig.apiKey))
        components.queryItems = items
        return components.url
    }
}

/// 外部服务返回结构的**占位模型**。字段按通用营养 API 的常见命名定义，
/// 接入真实服务时按对方文档调整即可。
struct ExternalNutritionResponse: Decodable {

    struct Item: Decodable {
        let name: String?
        let calories: Double?
        let protein_g: Double?
        let fat_g: Double?
        let carbohydrates_g: Double?
        let calcium_mg: Double?
        let iron_mg: Double?
        let vitamin_c_mg: Double?
        let fiber_g: Double?

        var nutrition: Nutrition {
            Nutrition(kcal: calories ?? 0,
                      proteinG: protein_g ?? 0,
                      fatG: fat_g ?? 0,
                      carbsG: carbohydrates_g ?? 0,
                      calciumMG: calcium_mg ?? 0,
                      ironMG: iron_mg ?? 0,
                      vitaminCMG: vitamin_c_mg ?? 0,
                      fiberG: fiber_g ?? 0)
        }
    }

    /// 有的服务返回数组，有的返回对象；两种都兼容。
    let items: [Item]?
    let item: Item?

    var firstNutrition: Nutrition? {
        if let item { return item.nutrition }
        return items?.first?.nutrition
    }
}
