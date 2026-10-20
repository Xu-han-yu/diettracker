//
//  ParsingSupport.swift
//  DietTracker
//
//  食物解析与运动解析共用的文本工具：
//    · 中文数字 → Double
//    · 份量识别（「两碗」「200克」「半份」）
//    · 时长识别（「30分钟」「1.5小时」「一刻钟」）
//    · 分句（把「米饭一碗、番茄炒蛋和牛奶」拆成三段）
//
//  全部纯本地、纯同步，可离线运行。
//

import Foundation

// MARK: - 中文数字

enum ChineseNumberParser {

    private static let digits: [Character: Int] = [
        "零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
    ]

    /// 支持：阿拉伯数字（含小数）、半、一~九、十、十一~十九、二十/三十…、二十一…
    static func parse(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }

        if t == "半" { return 0.5 }
        if let d = Double(t) { return d }

        let chars = Array(t)

        // 含「十」：十位处理
        if let idx = chars.firstIndex(of: "十") {
            let before = String(chars[chars.startIndex..<idx])
            let after = String(chars[chars.index(after: idx)...])

            var tens = 1
            if before.isEmpty {
                tens = 1                      // 十 / 十几
            } else if before.count == 1, let b = digits[before.first!] {
                tens = b                     // 二十 / 三十
            } else {
                return nil
            }

            var ones = 0
            if after.isEmpty {
                ones = 0                     // 十 / 二十
            } else if after.count == 1, let a = digits[after.first!] {
                ones = a                     // 十五 / 二十五
            } else {
                return nil
            }

            return Double(tens * 10 + ones)
        }

        // 单个汉字数字
        if chars.count == 1, let d = digits[chars[0]] { return Double(d) }

        return nil
    }
}

// MARK: - 份量

struct QuantityMatch: Hashable, Sendable {
    /// 命中的原始文本，例如「两碗」「200克」
    let text: String
    /// 数量，例如 2 / 200
    let value: Double
    /// 单位；nil 表示只有数字没有单位
    let unit: PortionUnit?
    /// 大 / 小的缩放系数
    let scale: Double

    var scaleText: String? {
        if scale > 1 { return "大" }
        if scale < 1 { return "小" }
        return nil
    }
}

enum QuantityParser {

    /// 数字部分：阿拉伯数字 / 1–3 个中文数字字符 / 「两」。
    ///
    /// ⚠️ 「两」必须单独作为**最后**一个分支：它同时是数词（两碗）和重量单位（两）。
    ///    若把它放进前面的字符类，「三两牛肉」会被贪心匹配成「三两」而找不到单位，
    ///    导致整句解析失败。拆开后：
    ///      「三两牛肉」→ 数词「三」+ 单位「两」= 150g  ✓
    ///      「两碗米饭」→ 数词「两」+ 单位「碗」= 300g  ✓
    private static let numberPart = "([0-9]+(?:\\.[0-9]+)?|[一二三四五六七八九十半]{1,3}|两)"
    /// 大小修饰
    private static let sizePart = "\\s*(大|小)?\\s*"
    /// 单位部分
    private static let unitPart = "(碗|份|个|只|颗|枚|杯|片|块|根|条|盘|碟|勺|匙|瓶|袋|包|把|克|g|G|毫升|ml|ML|两|斤)"

    private static let regex: NSRegularExpression? =
        try? NSRegularExpression(pattern: numberPart + sizePart + unitPart,
                                 options: [.caseInsensitive])

    /// 取文本中的第一个份量描述。
    static func firstMatch(in text: String) -> QuantityMatch? {
        guard let regex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, options: [], range: range) else { return nil }

        guard let numRange = Range(m.range(at: 1), in: text),
              let unitRange = Range(m.range(at: 3), in: text),
              let matchedRange = Range(m.range, in: text) else { return nil }

        guard let value = ChineseNumberParser.parse(String(text[numRange])) else { return nil }
        let unit = PortionUnit.from(text: String(text[unitRange]))

        var scale: Double = 1
        if m.range(at: 2).location != NSNotFound,
           let sizeRange = Range(m.range(at: 2), in: text) {
            switch String(text[sizeRange]) {
            case "大": scale = 1.25
            case "小": scale = 0.75
            default:  scale = 1
            }
        }

        return QuantityMatch(text: String(text[matchedRange]),
                             value: value,
                             unit: unit,
                             scale: scale)
    }
}

// MARK: - 时长

struct DurationMatch: Hashable, Sendable {
    let text: String
    let minutes: Double
}

enum DurationParser {

    private static let numberPart = "([0-9]+(?:\\.[0-9]+)?|[一二三四五六七八九十半]{1,3}|两)"
    // 长选项必须排在短选项前面，否则「1hours」只会吃掉「1h」而残留「ours」
    private static let hourPart = "(小时|钟头|hours|hr|h)"
    private static let minutePart = "(分钟|分|minutes|mins|min)"

    private static let hourRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: numberPart + "\\s*(?:个)?\\s*" + hourPart,
                                 options: [.caseInsensitive])

    private static let minuteRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: numberPart + "\\s*" + minutePart,
                                 options: [.caseInsensitive])

    /// 汇总文本里所有时长描述，返回分钟数。
    /// 用「求和」而不是「取第一个」，这样「1小时30分钟」= 90 分钟而不是 60。
    static func totalMinutes(in text: String) -> Double? {
        // 「一个半小时」= 90。必须整体优先识别：
        // 走正则的话会命中内部的「半小时」而算出 30，与语义不符。
        if text.contains("一个半小时") { return 90 }

        var total: Double = 0
        var found = false

        // 「一刻钟」= 15，正则覆盖不到（「刻」不是常规单位）
        if text.contains("一刻钟") { total += 15; found = true }

        if let hourRegex {
            let range = NSRange(text.startIndex..., in: text)
            for m in hourRegex.matches(in: text, options: [], range: range) {
                guard let numRange = Range(m.range(at: 1), in: text),
                      let v = ChineseNumberParser.parse(String(text[numRange])) else { continue }
                total += v * 60
                found = true
            }
        }

        if let minuteRegex {
            let range = NSRange(text.startIndex..., in: text)
            for m in minuteRegex.matches(in: text, options: [], range: range) {
                guard let numRange = Range(m.range(at: 1), in: text),
                      let v = ChineseNumberParser.parse(String(text[numRange])) else { continue }
                total += v
                found = true
            }
        }

        return found ? total : nil
    }

    /// 命中的原始文本（用于从句子里剔除后再做强度判断）。
    static func matchedTexts(in text: String) -> [String] {
        var result: [String] = []
        if text.contains("一个半小时") { return ["一个半小时"] }
        if text.contains("一刻钟") { result.append("一刻钟") }

        for regex in [hourRegex, minuteRegex].compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            for m in regex.matches(in: text, options: [], range: range) {
                guard let r = Range(m.range, in: text) else { continue }
                result.append(String(text[r]))
            }
        }
        return result
    }
}

// MARK: - 分句

enum TextSegmenter {

    /// 中文口语里最常见的并列连接。用非捕获组按顺序尝试，长词在前。
    private static let pattern =
        "[、，,。.;；/|\\n+]|还有|再加上|加上|以及|然后|接着|之后|和|与|加|跟"

    private static let regex: NSRegularExpression? = try? NSRegularExpression(pattern: pattern)

    /// 拆成若干段，去掉空白与空串。
    static func split(_ text: String) -> [String] {
        guard let regex else { return [text] }

        var segments: [String] = []
        var cursor = text.startIndex
        let range = NSRange(text.startIndex..., in: text)

        for m in regex.matches(in: text, options: [], range: range) {
            guard let r = Range(m.range, in: text) else { continue }
            let piece = String(text[cursor..<r.lowerBound])
            if !piece.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(piece.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            cursor = r.upperBound
        }

        if cursor < text.endIndex {
            let tail = String(text[cursor...])
            if !tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(tail.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        return segments.isEmpty ? [text] : segments
    }
}
