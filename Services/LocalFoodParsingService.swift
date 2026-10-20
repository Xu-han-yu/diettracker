//
//  LocalFoodParsingService.swift
//  DietTracker
//
//  本地食物解析：词典 + 正则 + 份量估算。
//
//  流程：
//    输入文本 → 分句 → 每段抽份量 → 剔除份量文本 → 最长别名匹配 → 查份量表算克数
//
//  ⚠️ 解析结果永远是「可修正的猜测」。只要 confidence < 0.8 或进了 unmatchedSegments，
//     UI 必须让用户能手动改（第 6 步的解析预览卡片负责这件事）。
//

import Foundation

struct LocalFoodParsingService: FoodParsingService {

    func parse(_ text: String) -> FoodParseResult {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return FoodParseResult.empty }

        let segments = TextSegmenter.split(raw)
        var items: [ParsedFood] = []
        var unmatched: [String] = []

        for segment in segments {
            let quantity = QuantityParser.firstMatch(in: segment)

            // 剔除份量文本后再匹配食物，避免「两碗」里的数词干扰别名命中
            var searchText = segment
            if let quantity {
                searchText = searchText.replacingOccurrences(of: quantity.text, with: "")
            }

            guard let hit = FoodDatabase.match(in: searchText) else {
                unmatched.append(segment)
                continue
            }

            let entry = hit.entry
            var confidence: Double = (hit.alias == entry.name) ? 0.95 : 0.88

            let grams: Double
            if let quantity {
                let perUnit = entry.grams(unit: quantity.unit)
                grams = perUnit * quantity.value * quantity.scale
                // 食物自身没有这个份量单位（且不是绝对重量单位）→ 用的是默认克数，置信度下调
                if let unit = quantity.unit,
                   !unit.isAbsoluteUnit,
                   entry.grams(for: unit) == nil {
                    confidence -= 0.05
                }
                // 「大碗」「小份」这类模糊修饰本身也是估算
                if quantity.scaleText != nil { confidence -= 0.03 }
            } else {
                grams = entry.defaultGrams
                confidence -= 0.08   // 没说份量，用的是默认份量
            }

            items.append(ParsedFood(
                name: entry.name,
                matchedFoodID: entry.id,
                quantityText: quantity?.text,
                grams: max(0, grams),
                confidence: max(0.3, min(1, confidence))
            ))
        }

        return FoodParseResult(rawText: raw, items: items, unmatchedSegments: unmatched)
    }
}
