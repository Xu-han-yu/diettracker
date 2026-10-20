//
//  DailyAnalysis.swift
//  DietTracker
//
//  AnalysisEngine 的输出。一份完整的「今日分析」。
//
//  ⚠️ 结构上的双通道隔离：
//     `microEvaluations`  —— 通道 A：钙/铁/维C/纤维，与运动完全无关
//     `macroEvaluations`  —— 通道 B：热量/蛋白/脂肪/碳水，可读取净能量与趋势
//     `energyBalance`     —— 描述性指标，不参与微量判定
//
//  `advice` 里的每一条都必须经过「补偿性进食」文案黑名单校验（第 5 步实现）。
//

import Foundation

// MARK: - 单营养素判定

/// 判定依据：状态是拿「当日值」判的，还是拿「近 N 日均值」判的。
///
/// 「判断和建议优先参考最近 7 天趋势」这条要求靠它落地 ——
/// 记录天数够时，状态由多日均值决定，单日波动不会让结论剧烈跳动。
struct EvaluationBasis: Codable, Equatable, Hashable, Sendable {
    var isMultiDay: Bool
    var windowDays: Int

    static let singleDay = EvaluationBasis(isMultiDay: false, windowDays: 1)

    static func multiDay(_ days: Int) -> EvaluationBasis {
        EvaluationBasis(isMultiDay: true, windowDays: max(days, 1))
    }

    /// UI 上标注状态来自哪个口径，例如「近 7 日均值」
    var label: String {
        isMultiDay ? "近 \(windowDays) 日均值" : "当日"
    }
}

struct NutrientEvaluation: Identifiable, Codable, Equatable, Sendable {
    var nutrient: Nutrient
    /// 当日实际值。**只用于展示**，不参与判定。
    var actual: Double
    /// 判定所用值：记录天数足够时 = 近 N 日均值，否则 = 当日值。
    var assessedValue: Double
    var basis: EvaluationBasis
    var target: Double
    var status: NutrientStatus

    init(nutrient: Nutrient,
         actual: Double,
         assessedValue: Double,
         basis: EvaluationBasis,
         target: Double,
         status: NutrientStatus) {
        self.nutrient = nutrient
        self.actual = actual
        self.assessedValue = assessedValue
        self.basis = basis
        self.target = target
        self.status = status
    }

    var id: String { nutrient.rawValue }

    /// 判定比值（基于 assessedValue）。target 为 0 时返回 0，避免 inf / nan 污染 UI。
    var ratio: Double {
        guard target > 0 else { return 0 }
        return assessedValue / target
    }

    /// 当日比值，只用于展示。
    var todayRatio: Double {
        guard target > 0 else { return 0 }
        return actual / target
    }

    /// 例如「82%」
    var percentText: String { Self.percent(ratio) }
    /// 当日的百分比，只用于展示
    var todayPercentText: String { Self.percent(todayRatio) }

    /// 例如「512 / 800 mg」——展示的是当日值
    var valueText: String {
        "\(Self.text(actual, nutrient)) / \(Self.text(target, nutrient)) \(nutrient.unit)"
    }

    /// 判定口径说明，例如「近 7 日均值 620 mg」
    var assessedText: String {
        "\(basis.label) \(Self.text(assessedValue, nutrient)) \(nutrient.unit)"
    }

    private static func percent(_ r: Double) -> String {
        "\(Int((r * 100).rounded()))%"
    }

    /// 按营养素的小数位规则格式化。不用 .formatted(.number) 是为了避免
    /// 不同区域设置下出现千分位逗号，仪表盘上数字宽度会跳。
    static func text(_ v: Double, _ nutrient: Nutrient) -> String {
        if nutrient.displayFractionDigits <= 0 { return "\(Int(v.rounded()))" }
        return String(format: "%.1f", v)
    }
}

// MARK: - 建议

enum AdviceCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case energy
    case protein
    case micronutrient
    case hydration
    case recovery
    case logging

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .energy:        return "能量"
        case .protein:       return "蛋白质"
        case .micronutrient: return "微量营养素"
        case .hydration:     return "补水"
        case .recovery:      return "恢复"
        case .logging:       return "记录"
        }
    }
}

struct AdviceItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var category: AdviceCategory
    /// 一句话结论，像营养师说话，不写空话
    var title: String
    /// 具体怎么做的补充说明
    var detail: String
    /// 明天可执行的具体动作（选填）
    var actionHint: String?

    init(id: UUID = UUID(),
         category: AdviceCategory,
         title: String,
         detail: String,
         actionHint: String? = nil) {
        self.id = id
        self.category = category
        self.title = title
        self.detail = detail
        self.actionHint = actionHint
    }
}

// MARK: - 分析结果

struct DailyAnalysis: Identifiable, Codable, Equatable, Sendable {

    var id: String { dayIdentifier }

    var dayIdentifier: String
    /// 当日摄入
    var intake: Nutrition
    /// 当日推荐量
    var target: NutritionProfile
    /// 当日运动消耗
    var burnKcal: Double
    /// 净摄入 = intake.kcal − burnKcal
    var netKcal: Double
    /// 能量平衡（描述性）
    var energyBalance: DailyEnergyBalance
    /// 全量判定结果
    var evaluations: [NutrientEvaluation]
    /// 中文建议，2–3 条
    var advice: [AdviceItem]
    /// 是否有足够天数做结论（false 时只展示数据，不下强结论）
    var hasEnoughData: Bool
    /// 窗口内实际有记录的天数
    var recordedDays: Int
    /// 趋势窗口天数
    var trendWindowDays: Int
    var generatedAt: Date
    var disclaimer: String

    init(dayIdentifier: String,
         intake: Nutrition,
         target: NutritionProfile,
         burnKcal: Double,
         energyBalance: DailyEnergyBalance,
         evaluations: [NutrientEvaluation],
         advice: [AdviceItem],
         hasEnoughData: Bool,
         recordedDays: Int,
         trendWindowDays: Int,
         generatedAt: Date = Date(),
         disclaimer: String = DailyAnalysis.disclaimerText) {
        self.dayIdentifier = dayIdentifier
        self.intake = intake
        self.target = target
        self.burnKcal = burnKcal
        self.netKcal = energyBalance.netKcal
        self.energyBalance = energyBalance
        self.evaluations = evaluations
        self.advice = advice
        self.hasEnoughData = hasEnoughData
        self.recordedDays = recordedDays
        self.trendWindowDays = trendWindowDays
        self.generatedAt = generatedAt
        self.disclaimer = disclaimer
    }

    static let disclaimerText = "本 App 数据为估算值，仅供参考，不能替代专业医疗或营养师建议。"

    // MARK: 通道隔离视图

    /// 通道 A：微量营养素。**调用方拿不到运动数据，物理隔离。**
    var microEvaluations: [NutrientEvaluation] {
        evaluations.filter { $0.nutrient.channel == .micronutrient }
            .sorted { $0.nutrient.displayIndex < $1.nutrient.displayIndex }
    }

    /// 通道 B：能量与宏量。
    var macroEvaluations: [NutrientEvaluation] {
        evaluations.filter { $0.nutrient.channel == .energyMacro }
            .sorted { $0.nutrient.displayIndex < $1.nutrient.displayIndex }
    }

    func evaluation(for nutrient: Nutrient) -> NutrientEvaluation? {
        evaluations.first { $0.nutrient == nutrient }
    }

    /// 处于「偏低」的微量营养素。**任何情况下都不能被运动量改写。**
    var deficientMicros: [NutrientEvaluation] {
        microEvaluations.filter { $0.status == .low }
    }
}
