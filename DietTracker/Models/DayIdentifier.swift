//
//  DayIdentifier.swift
//  DietTracker
//
//  全项目统一的「日」标识符：yyyy-MM-dd 字符串。
//
//  为什么不用 Date 做区间比较：
//   - 时区 / 夏令时切换会让「同一天」的边界漂移；
//   - 夜宵、夜跑这类跨午夜的记录容易被归到错误的一天；
//   - 查询用字符串精确匹配，比 Date 区间快且不会漏边界。
//
//  约定：所有持久化模型（MealEntry / ExerciseEntry / WaterEntry ...）
//  都必须同时存 `dayIdentifier` 与 `timestamp`。
//

import Foundation

enum DayIdentifier {

    /// 固定用公历，避免用户在系统设置里切到佛历 / 日本历导致 dayIdentifier 变化。
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    /// 由 Date 生成标识符（本地时区）。
    static func make(from date: Date = Date()) -> String {
        let comp = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comp.year ?? 1970
        let m = comp.month ?? 1
        let d = comp.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static var today: String { make() }

    /// 反解为当天 00:00 的 Date。解析失败返回 nil（调用方需处理）。
    static func date(from identifier: String) -> Date? {
        let parts = identifier.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comp = DateComponents()
        comp.calendar = calendar
        comp.year = parts[0]
        comp.month = parts[1]
        comp.day = parts[2]
        comp.hour = 0
        comp.minute = 0
        comp.second = 0
        return comp.date
    }

    /// 以 `endingAt` 为最后一天，倒推最近 `count` 天的标识符（升序返回）。
    static func recentIdentifiers(count: Int, endingAt: Date = Date()) -> [String] {
        guard count > 0 else { return [] }
        var result: [String] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: endingAt) else { continue }
            result.append(make(from: d))
        }
        return result
    }

    /// 两个标识符之间相差的天数（a - b）。解析失败返回 nil。
    static func daysBetween(_ a: String, _ b: String) -> Int? {
        guard let da = date(from: a), let db = date(from: b) else { return nil }
        return calendar.dateComponents([.day], from: db, to: da).day
    }

    /// 展示用：把 "2026-10-20" 变成 "10月20日"。
    static func displayText(_ identifier: String) -> String {
        let parts = identifier.split(separator: "-")
        guard parts.count == 3 else { return identifier }
        return "\(parts[1])月\(parts[2])日"
    }
}

extension Date {
    /// 便捷访问：`Date().dayIdentifier`
    var dayIdentifier: String { DayIdentifier.make(from: self) }
}
