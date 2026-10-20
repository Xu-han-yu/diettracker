//
//  LocalExerciseParsingService.swift
//  DietTracker
//
//  本地运动解析：运动词典 + 时长正则 + 强度关键词。
//
//  流程：
//    输入文本 → 分句 → 每段先匹配运动（最长别名）→ 剔除运动名 → 抽时长 → 判强度
//
//  ⚠️ 顺序很关键：必须先剔除运动名再判强度。
//     否则「快走」里的「快」会被当成高强度，把快走误判成冲刺。
//

import Foundation

struct LocalExerciseParsingService: ExerciseParsingService {

    func parse(_ text: String) -> ExerciseParseResult {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return ExerciseParseResult.empty }

        let segments = TextSegmenter.split(raw)
        var items: [ParsedExercise] = []
        var unmatched: [String] = []

        for segment in segments {
            var searchText = segment
            var matchedEntry: ExerciseEntryData?
            var matchedAlias: String?

            // 1) 先匹配运动名（最长别名优先）
            if let hit = ExerciseDatabase.match(in: searchText) {
                matchedEntry = hit.entry
                matchedAlias = hit.alias
                searchText = searchText.replacingOccurrences(of: hit.alias, with: "")
            }

            // 2) 抽时长
            let minutes = DurationParser.totalMinutes(in: searchText)
            for t in DurationParser.matchedTexts(in: searchText) {
                searchText = searchText.replacingOccurrences(of: t, with: "")
            }

            // 3) 剔除运动名与时长之后，剩下的词才用于判强度
            let intensity = detectIntensity(in: searchText)

            guard let entry = matchedEntry else {
                unmatched.append(segment)
                continue
            }

            var confidence: Double = (matchedAlias == entry.name) ? 0.95 : 0.88
            if minutes == nil { confidence -= 0.10 }   // 没说时长，用默认时长
            if intensity == nil { confidence -= 0.02 } // 没说强度，默认中等

            items.append(ParsedExercise(
                name: entry.name,
                matchedExerciseID: entry.id,
                minutes: minutes,
                intensity: intensity,
                confidence: max(0.3, min(1, confidence))
            ))
        }

        return ExerciseParseResult(rawText: raw, items: items, unmatchedSegments: unmatched)
    }

    // MARK: 强度关键词

    private static let highKeywords = ["冲刺", "剧烈", "高强度", "全力", "拼命", "竞速", "飞快", "很快", "快", "猛"]
    private static let lowKeywords = ["慢速", "低强度", "轻松", "悠闲", "慢慢", "慢跑", "慢", "缓缓"]

    /// 只在剔除运动名后的剩余文本里判断，避免「快走」被判成高强度。
    private func detectIntensity(in text: String) -> ExerciseIntensity? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }

        // 长词优先，避免「慢」先命中导致「慢速」被误判
        if Self.highKeywords.contains(where: { t.contains($0) }) { return .high }
        if Self.lowKeywords.contains(where: { t.contains($0) }) { return .low }
        return nil
    }
}
