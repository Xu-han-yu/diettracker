//
//  ExerciseDatabase.swift
//  DietTracker
//
//  本地运动 MET 表。≥20 种常见运动 × 低/中/高三档强度。
//
//  估算公式（ExerciseCalorieService 使用）：
//      消耗 kcal = MET × 体重kg × 小时数
//
//  MET 值参考 Ainsworth 体力活动概要（Compendium of Physical Activities）的常见取值，
//  按中式说法做了本地化（如「快走」「广场舞」）。**全部为估算值。**
//
//  ⚠️ 强度分档语义：
//     low      —— 轻松、能边做边聊天
//     moderate —— 微微出汗、说话略有喘
//     high     —— 明显吃力、说话困难
//

import Foundation

enum ExerciseCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case cardio
    case strength
    case flexibility
    case sports
    case daily

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cardio:     return "有氧"
        case .strength:   return "力量"
        case .flexibility: return "柔韧"
        case .sports:     return "球类"
        case .daily:      return "日常"
        }
    }
}

struct ExerciseEntryData: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// 别名。注意：别名里带「快」「慢」字样的（如「快走」）会在解析后先被剔除，
    /// 因此不会被强度关键词误判。见 LocalExerciseParsingService。
    let aliases: [String]
    let category: ExerciseCategory
    /// 低强度 MET
    let metLow: Double
    /// 中等强度 MET
    let metModerate: Double
    /// 高强度 MET
    let metHigh: Double
    /// 用户没说时长时的默认分钟数
    let defaultMinutes: Double

    func met(for intensity: ExerciseIntensity) -> Double {
        switch intensity {
        case .low:      return metLow
        case .moderate: return metModerate
        case .high:     return metHigh
        }
    }
}

enum ExerciseDatabase {

    static let all: [ExerciseEntryData] = [

        // ---------------- 有氧 ----------------
        ExerciseEntryData(id: "running", name: "跑步",
                          aliases: ["跑步", "慢跑", "快跑", "跑步机", "跑"],
                          category: .cardio,
                          metLow: 8.3, metModerate: 11.0, metHigh: 14.5,
                          defaultMinutes: 30),

        ExerciseEntryData(id: "brisk_walking", name: "快走",
                          aliases: ["快走", "快步走", "竞走", "健步走"],
                          category: .cardio,
                          metLow: 3.5, metModerate: 4.3, metHigh: 5.5,
                          defaultMinutes: 40),

        ExerciseEntryData(id: "walking", name: "走路",
                          aliases: ["走路", "散步", "步行", "溜达", "慢走"],
                          category: .cardio,
                          metLow: 2.0, metModerate: 3.0, metHigh: 4.3,
                          defaultMinutes: 40),

        ExerciseEntryData(id: "cycling", name: "骑车",
                          aliases: ["骑车", "骑自行车", "自行车", "动感单车", "骑行"],
                          category: .cardio,
                          metLow: 5.8, metModerate: 7.5, metHigh: 10.0,
                          defaultMinutes: 30),

        ExerciseEntryData(id: "swimming", name: "游泳",
                          aliases: ["游泳", "自由泳", "蛙泳", "游"],
                          category: .cardio,
                          metLow: 5.8, metModerate: 7.0, metHigh: 10.0,
                          defaultMinutes: 30),

        ExerciseEntryData(id: "jump_rope", name: "跳绳",
                          aliases: ["跳绳"],
                          category: .cardio,
                          metLow: 8.8, metModerate: 11.8, metHigh: 12.3,
                          defaultMinutes: 15),

        ExerciseEntryData(id: "elliptical", name: "椭圆机",
                          aliases: ["椭圆机", "椭圆仪"],
                          category: .cardio,
                          metLow: 4.0, metModerate: 5.0, metHigh: 7.0,
                          defaultMinutes: 30),

        ExerciseEntryData(id: "rowing", name: "划船机",
                          aliases: ["划船机", "划船", "赛艇"],
                          category: .cardio,
                          metLow: 4.8, metModerate: 7.0, metHigh: 8.5,
                          defaultMinutes: 20),

        ExerciseEntryData(id: "stair_climbing", name: "爬楼梯",
                          aliases: ["爬楼梯", "爬楼", "走楼梯"],
                          category: .cardio,
                          metLow: 4.0, metModerate: 6.0, metHigh: 8.8,
                          defaultMinutes: 15),

        ExerciseEntryData(id: "hiking", name: "登山",
                          aliases: ["登山", "爬山", "徒步", "爬山远足"],
                          category: .cardio,
                          metLow: 5.0, metModerate: 6.0, metHigh: 7.5,
                          defaultMinutes: 60),

        ExerciseEntryData(id: "hiit", name: "HIIT",
                          aliases: ["hiit", "高强度间歇", "间歇训练", "燃脂训练"],
                          category: .cardio,
                          metLow: 6.0, metModerate: 8.0, metHigh: 10.0,
                          defaultMinutes: 20),

        ExerciseEntryData(id: "aerobics", name: "有氧操",
                          aliases: ["有氧操", "健身操", "跳操", "帕梅拉"],
                          category: .cardio,
                          metLow: 4.5, metModerate: 6.5, metHigh: 8.5,
                          defaultMinutes: 30),

        ExerciseEntryData(id: "dance", name: "跳舞",
                          aliases: ["跳舞", "舞蹈", "广场舞", "街舞"],
                          category: .cardio,
                          metLow: 3.0, metModerate: 5.0, metHigh: 7.8,
                          defaultMinutes: 30),

        // ---------------- 力量 ----------------
        ExerciseEntryData(id: "strength", name: "力量训练",
                          aliases: ["力量训练", "撸铁", "器械", "力量", "举铁"],
                          category: .strength,
                          metLow: 3.5, metModerate: 5.0, metHigh: 6.0,
                          defaultMinutes: 40),

        ExerciseEntryData(id: "weightlifting", name: "举重",
                          aliases: ["举重", "哑铃", "杠铃", "卧推", "深蹲", "硬拉"],
                          category: .strength,
                          metLow: 3.0, metModerate: 5.0, metHigh: 6.0,
                          defaultMinutes: 30),

        ExerciseEntryData(id: "bodyweight", name: "自重训练",
                          aliases: ["俯卧撑", "仰卧起坐", "平板支撑", "引体向上", "自重训练"],
                          category: .strength,
                          metLow: 3.5, metModerate: 5.0, metHigh: 8.0,
                          defaultMinutes: 20),

        ExerciseEntryData(id: "boxing", name: "拳击",
                          aliases: ["拳击", "打拳", "搏击", "散打"],
                          category: .strength,
                          metLow: 5.0, metModerate: 7.8, metHigh: 9.5,
                          defaultMinutes: 30),

        // ---------------- 柔韧 ----------------
        ExerciseEntryData(id: "yoga", name: "瑜伽",
                          aliases: ["瑜伽", "瑜珈"],
                          category: .flexibility,
                          metLow: 2.0, metModerate: 3.0, metHigh: 4.0,
                          defaultMinutes: 40),

        ExerciseEntryData(id: "pilates", name: "普拉提",
                          aliases: ["普拉提"],
                          category: .flexibility,
                          metLow: 2.5, metModerate: 3.0, metHigh: 4.0,
                          defaultMinutes: 40),

        ExerciseEntryData(id: "stretching", name: "拉伸",
                          aliases: ["拉伸", "柔韧训练", "放松训练"],
                          category: .flexibility,
                          metLow: 1.8, metModerate: 2.3, metHigh: 3.0,
                          defaultMinutes: 15),

        ExerciseEntryData(id: "tai_chi", name: "太极",
                          aliases: ["太极", "太极拳", "八段锦"],
                          category: .flexibility,
                          metLow: 1.5, metModerate: 3.0, metHigh: 4.0,
                          defaultMinutes: 30),

        // ---------------- 球类 ----------------
        ExerciseEntryData(id: "basketball", name: "篮球",
                          aliases: ["篮球", "打篮球", "投篮"],
                          category: .sports,
                          metLow: 4.5, metModerate: 6.5, metHigh: 8.0,
                          defaultMinutes: 45),

        ExerciseEntryData(id: "soccer", name: "足球",
                          aliases: ["足球", "踢足球", "踢球"],
                          category: .sports,
                          metLow: 5.0, metModerate: 7.0, metHigh: 10.0,
                          defaultMinutes: 45),

        ExerciseEntryData(id: "badminton", name: "羽毛球",
                          aliases: ["羽毛球", "打羽毛球"],
                          category: .sports,
                          metLow: 3.5, metModerate: 5.5, metHigh: 7.0,
                          defaultMinutes: 45),

        ExerciseEntryData(id: "table_tennis", name: "乒乓球",
                          aliases: ["乒乓球", "桌球", "打乒乓"],
                          category: .sports,
                          metLow: 3.0, metModerate: 4.0, metHigh: 5.5,
                          defaultMinutes: 40),

        ExerciseEntryData(id: "tennis", name: "网球",
                          aliases: ["网球", "打网球"],
                          category: .sports,
                          metLow: 4.0, metModerate: 6.0, metHigh: 8.0,
                          defaultMinutes: 45),

        ExerciseEntryData(id: "volleyball", name: "排球",
                          aliases: ["排球", "打排球"],
                          category: .sports,
                          metLow: 3.0, metModerate: 4.0, metHigh: 6.0,
                          defaultMinutes: 45),

        // ---------------- 日常 / 其他 ----------------
        ExerciseEntryData(id: "skating", name: "滑冰轮滑",
                          aliases: ["滑冰轮滑", "滑冰", "轮滑", "溜冰", "滑旱冰", "滑板"],
                          category: .daily,
                          metLow: 5.0, metModerate: 7.0, metHigh: 9.0,
                          defaultMinutes: 30),

        ExerciseEntryData(id: "skiing", name: "滑雪",
                          aliases: ["滑雪", "单板", "双板"],
                          category: .daily,
                          metLow: 4.3, metModerate: 6.0, metHigh: 8.0,
                          defaultMinutes: 60),

        ExerciseEntryData(id: "housework", name: "家务",
                          aliases: ["家务", "做家务", "打扫卫生", "拖地", "擦地"],
                          category: .daily,
                          metLow: 2.3, metModerate: 3.5, metHigh: 4.5,
                          defaultMinutes: 40),

        ExerciseEntryData(id: "dog_walking", name: "遛狗",
                          aliases: ["遛狗", "遛弯"],
                          category: .daily,
                          metLow: 2.0, metModerate: 3.0, metHigh: 4.0,
                          defaultMinutes: 30)
    ]

    // MARK: 索引

    static let aliasIndex: [(alias: String, entry: ExerciseEntryData)] = {
        var pairs: [(String, ExerciseEntryData)] = []
        for entry in all {
            for alias in entry.aliases {
                pairs.append((alias, entry))
            }
        }
        return pairs.sorted { $0.0.count > $1.0.count }
    }()

    static func entry(id: String) -> ExerciseEntryData? {
        all.first { $0.id == id }
    }

    /// 在文本中找最长命中的运动。
    static func match(in text: String) -> (entry: ExerciseEntryData, alias: String)? {
        for (alias, entry) in aliasIndex {
            if text.contains(alias) { return (entry, alias) }
        }
        return nil
    }

    static func search(_ keyword: String) -> [ExerciseEntryData] {
        let k = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        guard !k.isEmpty else { return [] }
        return all.filter { entry in
            entry.name.lowercased().contains(k) ||
            entry.aliases.contains { $0.lowercased().contains(k) }
        }
    }
}
