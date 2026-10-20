//
//  DefaultAnalysisEngine.swift
//  DietTracker
//
//  AnalysisEngine 的默认实现（第 5 步）。
//
//  ⚠️ 三条硬约束在这里落地：
//
//   1. RDI 不含运动回加。
//      rdi 全部来自 NutritionProfile.compute(from:)，全链路不读 burnKcal，
//      所以「跑了 5 公里所以能吃回去」在计算上就不可能发生。
//
//   2. 双通道物理隔离。
//      通道 A（钙/铁/维C/纤维）：MicronutrientJudge.Input 里**没有任何运动字段**，
//          判定和建议生成都拿不到 burnKcal，运动量再大也改不了「偏低」。
//      通道 B（热量/蛋白/脂肪/碳水）：状态判定同样只看「摄入 vs RDI」（判定主线一致），
//          净能量与多日趋势只进入 EnergyAdviceFactory / DeficitRecoveryAdvice 等建议生成器。
//      两者唯一的差异在**建议层**，这正是设计意图：运动可以说清楚能量缺口，
//      但不能碰营养素是否达标。
//
//   3. 建议文案黑名单。
//      生成后统一过 CompensationWordingGuard，命中「补回来 / 可以多吃 / 奖励自己 …」直接丢弃。
//
//  纯函数实现：同样输入必得同样输出，不读写数据库、不发网络请求，便于单测。
//

import Foundation

// MARK: - 数值格式化

enum AnalysisFormat {

    /// kcal 一律取整，仪表盘上不需要小数
    static func kcal(_ v: Double) -> String { "\(Int(v.rounded()))" }

    /// 按营养素的小数位规则输出数值
    static func value(_ v: Double, for nutrient: Nutrient) -> String {
        NutrientEvaluation.text(v, nutrient)
    }

    static func percent(_ ratio: Double) -> String { "\(Int((ratio * 100).rounded()))%" }

    /// 「今天」/「最近 7 天」这类口径前缀，保证文案和判定口径一致
    static func clause(_ basis: EvaluationBasis) -> String {
        basis.isMultiDay ? "最近 \(basis.windowDays) 天" : "今天"
    }
}

// MARK: - 趋势快照

/// 趋势窗口内的统计量。判定与建议都从这里取数，不直接翻 history。
struct TrendSnapshot: Sendable {

    var windowDays: Int
    /// 窗口内实际有记录的天数
    var recordedDays: Int
    /// 各营养素在窗口内的日均值
    var averages: [Nutrient: Double]
    var averageIntakeKcal: Double
    var averageBurnKcal: Double
    var averageNetKcal: Double
    /// 窗口内有运动记录的天数
    var daysWithExercise: Int

    static func empty(windowDays: Int) -> TrendSnapshot {
        TrendSnapshot(windowDays: windowDays,
                      recordedDays: 0,
                      averages: [:],
                      averageIntakeKcal: 0,
                      averageBurnKcal: 0,
                      averageNetKcal: 0,
                      daysWithExercise: 0)
    }

    func average(of nutrient: Nutrient) -> Double { averages[nutrient] ?? 0 }

    /// 净摄入相对推荐量的缺口。正数 = 净摄入低于推荐量。
    func netGap(againstRDI rdiKcal: Double) -> Double { rdiKcal - averageNetKcal }
}

extension Array where Element == DailySummary {

    /// 取窗口内**有记录**的天，算各营养素日均值。
    ///
    /// 分母是「有记录的天数」而不是「窗口天数」：没记录的那天多半是忘了记，
    /// 用 0 去拉低均值只会让结论失真。这个取舍在第 7 步验收时要明确说明。
    func trendSnapshot(windowDays: Int) -> TrendSnapshot {
        let sorted = recordedAndSorted
        let window = windowDays > 0 ? Array(sorted.suffix(windowDays)) : sorted
        guard !window.isEmpty else { return .empty(windowDays: max(windowDays, 1)) }

        let count = Double(window.count)
        var averages: [Nutrient: Double] = [:]
        for nutrient in Nutrient.displayOrder {
            averages[nutrient] = window.reduce(0) { $0 + $1.intake.value(for: nutrient) } / count
        }

        let intake = window.reduce(0) { $0 + $1.intake.kcal } / count
        let burn = window.reduce(0) { $0 + $1.burnKcal } / count

        return TrendSnapshot(windowDays: max(windowDays, 1),
                             recordedDays: window.count,
                             averages: averages,
                             averageIntakeKcal: intake,
                             averageBurnKcal: burn,
                             averageNetKcal: intake - burn,
                             daysWithExercise: window.filter { $0.burnKcal > 0 }.count)
    }
}

// MARK: - 通道 A：微量营养素

/// 通道 A 的判定器。
///
/// ⚠️ 这是全项目唯一能给微量营养素定状态的地方，而它的 Input **没有运动字段** ——
///    不是「记得别用」，是「根本拿不到」。想让运动改写「钙偏低」也没门。
enum MicronutrientJudge {

    struct Input: Sendable {
        var nutrient: Nutrient
        var actual: Double
        var assessedValue: Double
        var basis: EvaluationBasis
        var target: Double
    }

    static func evaluate(_ input: Input, thresholds: AnalysisThresholds) -> NutrientEvaluation {
        NutrientEvaluation(nutrient: input.nutrient,
                           actual: input.actual,
                           assessedValue: input.assessedValue,
                           basis: input.basis,
                           target: input.target,
                           status: thresholds.status(actual: input.assessedValue,
                                                     target: input.target))
    }
}

// MARK: - 通道 B：能量与宏量

/// 通道 B 的判定器。
///
/// 状态判定和通道 A 用的是同一条主线：摄入 vs RDI。
/// 这不是偷懒 —— 判定主线必须一致，否则「热量按净摄入算、蛋白按摄入算」
/// 会让同一张卡片里的口径互相打架。通道 B 的「看得到运动」体现在建议层
/// （EnergyAdviceFactory / DeficitRecoveryAdvice），那里才会读净能量与趋势。
enum EnergyMacroJudge {

    struct Input: Sendable {
        var nutrient: Nutrient
        var actual: Double
        var assessedValue: Double
        var basis: EvaluationBasis
        var target: Double
    }

    static func evaluate(_ input: Input, thresholds: AnalysisThresholds) -> NutrientEvaluation {
        NutrientEvaluation(nutrient: input.nutrient,
                           actual: input.actual,
                           assessedValue: input.assessedValue,
                           basis: input.basis,
                           target: input.target,
                           status: thresholds.status(actual: input.assessedValue,
                                                     target: input.target))
    }
}

// MARK: - 建议生成：微量营养素（通道 A）

/// 微量营养素的建议生成器。
///
/// ⚠️ Fact 里没有运动字段，这个工厂在物理上不可能写出
///    「今天运动了所以钙不算缺」这类文案。
enum MicronutrientAdviceFactory {

    struct Fact: Sendable {
        var nutrient: Nutrient
        var actual: Double
        var assessedValue: Double
        var basis: EvaluationBasis
        var target: Double
        var status: NutrientStatus

        var ratio: Double {
            guard target > 0 else { return 0 }
            return assessedValue / target
        }
    }

    static func make(facts: [Fact]) -> AdviceItem? {
        let lows = facts.filter { $0.status == .low }.sorted { $0.ratio < $1.ratio }

        if let worst = lows.first {
            return deficiencyAdvice(worst: worst, alsoLow: Array(lows.dropFirst()))
        }
        return highOnlyAdvice(facts: facts)
    }

    private static func deficiencyAdvice(worst: Fact, alsoLow: [Fact]) -> AdviceItem {
        let n = worst.nutrient
        let pct = AnalysisFormat.percent(worst.ratio)
        let shown = NutrientEvaluation.text(worst.assessedValue, n)

        let title: String
        if worst.basis.isMultiDay {
            title = "最近 \(worst.basis.windowDays) 天\(n.displayName)日均 \(shown) \(n.unit)，只有推荐量的 \(pct)"
        } else {
            title = "今天\(n.displayName)约 \(shown) \(n.unit)，只有推荐量的 \(pct)"
        }

        var detail = causeText(for: n)
        if !alsoLow.isEmpty {
            let names = alsoLow.map { $0.nutrient.displayName }.joined(separator: "、")
            detail += "另外\(names)近期也偏低，可以在同一餐里顺带解决。"
        }
        if !worst.basis.isMultiDay {
            detail += "单日数字波动很正常，先记着，积累几天再看是不是常态。"
        }

        return AdviceItem(category: .micronutrient,
                          title: title,
                          detail: detail,
                          actionHint: "明天加一份：\(foodText(for: n))")
    }

    /// 只有「铁」偏高需要提醒；钙 / 维C / 纤维偏高一般无需处理。
    private static func highOnlyAdvice(facts: [Fact]) -> AdviceItem? {
        let highs = facts.filter { $0.status == .high }
        guard let iron = highs.first(where: { $0.nutrient == .iron }) else { return nil }

        let shown = NutrientEvaluation.text(iron.assessedValue, .iron)
        return AdviceItem(
            category: .micronutrient,
            title: "\(AnalysisFormat.clause(iron.basis))铁约 \(shown) mg，高于推荐量",
            detail: "膳食铁偏高通常来自补充剂或动物肝脏吃得频繁。铁过量会在体内蓄积，如果同时在吃含铁的补充剂，建议留意一下摄入总量。",
            actionHint: "检查一下补充剂标签上的铁含量，必要时咨询医生或营养师。")
    }

    private static func causeText(for n: Nutrient) -> String {
        switch n {
        case .calcium:
            return "钙主要来自奶制品、豆制品和深绿色蔬菜，一顿饭很难凑够，分散到三餐更现实。"
        case .iron:
            return "红肉、动物血和肝脏里的铁更容易吸收；植物来源的铁和富含维生素 C 的食物同餐吃，吸收率会好一些。"
        case .vitaminC:
            return "维生素 C 基本靠新鲜蔬果，而且加热容易损失，能生吃的就生吃，炒的话快炒更好。"
        case .fiber:
            return "膳食纤维来自全谷物、豆类、蔬果和坚果，把精白主食换掉一部分是最省事的做法。"
        case .energy, .protein, .fat, .carbs:
            return "可以在明天的三餐里安排上相应食材。"
        }
    }

    private static func foodText(for n: Nutrient) -> String {
        switch n {
        case .calcium:
            return "牛奶或酸奶 250 ml（约 300 mg 钙），或北豆腐 100 g，或小油菜 / 芥蓝一盘"
        case .iron:
            return "瘦牛肉或猪肝 50–75 g，配青椒、番茄这类富含维生素 C 的菜一起吃"
        case .vitaminC:
            return "猕猴桃 1 个或橙子 1 个，或者一份清炒青椒 / 西兰花"
        case .fiber:
            return "把一顿白米饭换成燕麦、糙米或红薯，再加一份豆类"
        case .energy, .protein, .fat, .carbs:
            return "对应食材"
        }
    }
}

// MARK: - 建议生成：能量（通道 B）

/// 唯一读取「净能量 + 多日趋势」的建议生成器。目标不同，判断口径也不同。
enum EnergyAdviceFactory {

    struct Input: Sendable {
        var goal: Goal
        var rdiKcal: Double
        var todayIntakeKcal: Double
        var todayBurnKcal: Double
        var trend: TrendSnapshot
        var basis: EvaluationBasis
        var hasEnoughData: Bool
    }

    /// 参考值：数据够就看窗口均值，不够就看今天。
    private struct Reference {
        var intakeKcal: Double
        var burnKcal: Double
        var netKcal: Double
        var clause: String
    }

    static func make(_ input: Input) -> AdviceItem? {
        let ref = Reference(
            intakeKcal: input.hasEnoughData ? input.trend.averageIntakeKcal : input.todayIntakeKcal,
            burnKcal: input.hasEnoughData ? input.trend.averageBurnKcal : input.todayBurnKcal,
            netKcal: input.hasEnoughData ? input.trend.averageNetKcal : (input.todayIntakeKcal - input.todayBurnKcal),
            clause: AnalysisFormat.clause(input.basis))

        guard input.rdiKcal > 0 else { return nil }

        // 正数 = 净摄入低于推荐量
        let gap = input.rdiKcal - ref.netKcal
        let magnitude = AnalysisFormat.kcal(abs(gap))

        let objective = "\(ref.clause)日均摄入 \(AnalysisFormat.kcal(ref.intakeKcal)) kcal、运动消耗 \(AnalysisFormat.kcal(ref.burnKcal)) kcal，净摄入约 \(AnalysisFormat.kcal(ref.netKcal)) kcal，推荐量 \(AnalysisFormat.kcal(input.rdiKcal)) kcal。"

        // 用 var 而不是 let 元组：let 的条件初始化在元组解构上依赖编译器的
        // 确定初始化分析，云端换编译器版本有风险，这里写成显式赋值最稳。
        var title = ""
        var detail = ""
        switch input.goal {
        case .maintain:
            (title, detail) = maintainText(gap: gap, magnitude: magnitude, objective: objective, input: input)

        case .cut:
            (title, detail) = cutText(gap: gap, magnitude: magnitude, objective: objective, input: input)

        case .bulk:
            (title, detail) = bulkText(gap: gap, magnitude: magnitude, objective: objective, input: input)
        }

        return AdviceItem(category: .energy,
                          title: title,
                          detail: detail,
                          actionHint: actionHint(goal: input.goal, gap: gap))
    }

    // MARK: 分目标文案

    private static func maintainText(gap: Double,
                                     magnitude: String,
                                     objective: String,
                                     input: Input) -> (String, String) {
        if gap > 300 {
            return ("净摄入比推荐量低约 \(magnitude) kcal",
                    objective + "维持期长期这样会慢慢掉体重。如果不是有意为之，先把摄入往上提一点，比继续观察更稳妥。")
        }
        if gap < -300 {
            return ("净摄入比推荐量高约 \(magnitude) kcal",
                    objective + "维持期持续盈余，体重会缓慢上升。可以先从晚餐的主食或油脂入手收一收。")
        }
        return ("净摄入与推荐量基本持平",
                objective + "维持期这个状态就挺好，接下来主要是看微量营养素有没有短板。")
    }

    private static func cutText(gap: Double,
                                magnitude: String,
                                objective: String,
                                input: Input) -> (String, String) {
        if gap < -100 {
            return ("净摄入比推荐量高约 \(magnitude) kcal，减脂节奏会被拖慢",
                    objective + "推荐量本身已经打了八折，再高就接近维持水平了。先别急着加运动量，把摄入收回到推荐量附近更直接。")
        }
        if gap <= 100 {
            return ("净摄入与推荐量基本持平，这是减脂期比较理想的位置",
                    objective + "推荐量已经按减脂打过折，吃到这个位置本身就形成了缺口，不需要再往下压。\(exerciseClause(input: input))")
        }
        if gap <= 500 {
            return ("净摄入比推荐量低约 \(magnitude) kcal，落在常见减脂区间",
                    objective + "这个幅度对大多数人是可以长期坚持的。\(exerciseClause(input: input))")
        }
        if gap <= 900 {
            return ("净摄入缺口约 \(magnitude) kcal，比常见减脂区间更深一些",
                    objective + "短期问题不大，但连续两三周都这么深，容易掉肌肉、训练状态也会跟着下滑。\(exerciseClause(input: input))")
        }
        return ("净摄入缺口约 \(magnitude) kcal，明显偏大",
                objective + "这个缺口已经超出多数人能长期维持的范围，疲劳感和暴食风险都会上升。建议先把摄入往推荐量方向提，而不是继续往下压。")
    }

    private static func bulkText(gap: Double,
                                 magnitude: String,
                                 objective: String,
                                 input: Input) -> (String, String) {
        if gap < -100 {
            return ("净摄入比推荐量高约 \(magnitude) kcal，盈余比较充足",
                    objective + "增肌期这个盈余是合理的，接下来重点看蛋白质有没有跟上。")
        }
        if gap <= 200 {
            return ("净摄入和推荐量基本持平，盈余够用",
                    objective + "推荐量已经上浮了 10%，维持在这个位置就行，重点放在蛋白质和训练上。\(exerciseClause(input: input))")
        }
        return ("净摄入还差推荐量约 \(magnitude) kcal，盈余不够",
                objective + "增肌需要净摄入高于日常消耗。运动量大的话，摄入要跟着往上加，不然练得越多缺口越大。\(exerciseClause(input: input))")
    }

    /// 运动相关的客观说明。只描述事实与后果，不暗示「所以能多吃」。
    private static func exerciseClause(input: Input) -> String {
        guard input.trend.daysWithExercise > 0 else { return "" }
        let d = input.trend.daysWithExercise
        let w = input.trend.windowDays
        return "窗口内 \(d) / \(w) 天有运动记录，运动让净摄入进一步降低 —— 这是正常的，但摄入也要跟着跟上，别让缺口越滚越大。"
    }

    private static func actionHint(goal: Goal, gap: Double) -> String {
        if gap > 500 {
            return "明天先在一餐里加一份主食或一份蛋白质，把净摄入往推荐量方向提一提。"
        }
        if gap < -300 {
            return "明天先从晚餐的主食或烹调油下手，减一点就行，不用一次砍太多。"
        }
        switch goal {
        case .cut:      return "维持现在的摄入水平，重点盯住蛋白质和微量营养素。"
        case .bulk:     return "明天加一份主食 + 一份蛋白质，把盈余补出来。"
        case .maintain: return "保持现在的节奏，继续记录就行。"
        }
    }
}

// MARK: - 建议生成：蛋白质（通道 B）

enum ProteinAdviceFactory {

    struct Input: Sendable {
        var evaluation: NutrientEvaluation
        var goal: Goal
        var weightKg: Double
    }

    static func make(_ input: Input) -> AdviceItem? {
        guard input.evaluation.status == .low else { return nil }

        let e = input.evaluation
        let n = e.nutrient
        let pct = AnalysisFormat.percent(e.ratio)
        let shown = NutrientEvaluation.text(e.assessedValue, n)
        let weight = Int(input.weightKg.rounded())

        let goalClause: String
        switch input.goal {
        case .cut:      goalClause = "减脂期热量本身就在往下压，蛋白质不够的话掉的主要是肌肉而不是脂肪。"
        case .bulk:     goalClause = "增肌期蛋白质是硬指标，摄入跟不上，训练带来的刺激很难变成肌肉。"
        case .maintain: goalClause = "蛋白质长期不足会影响饱腹感和身体成分。"
        }

        return AdviceItem(
            category: .protein,
            title: "\(AnalysisFormat.clause(e.basis))蛋白质约 \(shown) g，只有推荐量的 \(pct)",
            detail: "按你 \(weight) kg 体重，目标蛋白约 \(NutrientEvaluation.text(e.target, n)) g/天。\(goalClause)",
            actionHint: "明天加一份：鸡蛋 2 个 + 牛奶 250 ml（约 20 g 蛋白），或鸡胸肉 / 瘦肉 100 g（约 25 g）。")
    }
}

// MARK: - 建议生成：补水（运动相关，允许方向之一）

enum HydrationAdviceFactory {

    struct Input: Sendable {
        var todayBurnKcal: Double
    }

    static func make(_ input: Input) -> AdviceItem? {
        guard input.todayBurnKcal > 0 else { return nil }
        return AdviceItem(
            category: .hydration,
            title: "今天有约 \(AnalysisFormat.kcal(input.todayBurnKcal)) kcal 的运动消耗，记得补水",
            detail: "运动前后各喝 200–300 ml 水，出汗多的时候再往上加。出汗量不等于消耗量，别拿它判断训练效果。",
            actionHint: "把今天的饮水也记上，目标 1500–2000 ml，按体重和出汗量调整。")
    }
}

// MARK: - 建议生成：恢复 / 运动日碳水（运动相关，允许方向之一）

enum RecoveryAdviceFactory {

    struct Input: Sendable {
        var todayBurnKcal: Double
        var trend: TrendSnapshot
    }

    static func make(_ input: Input) -> AdviceItem? {
        let t = input.trend
        // 今天消耗够大，或窗口内运动天数够多，才值得提醒
        guard input.todayBurnKcal >= 350 || t.daysWithExercise >= 2 else { return nil }

        return AdviceItem(
            category: .recovery,
            title: "有运动的日子别把碳水压太低",
            detail: "最近 \(t.windowDays) 天里有 \(t.daysWithExercise) 天运动记录。碳水是训练的主要燃料，压得太低会直接影响训练质量和恢复速度。",
            actionHint: "明天训练前后各安排一份主食，配一份蛋白质。")
    }
}

// MARK: - 建议生成：缺口过大 + 有运动

/// 允许的运动相关方向之三：客观说明运动与能量缺口的关系。
/// 注意这里说的是「摄入要跟上」，不是「运动了所以能吃」。
enum DeficitRecoveryAdvice {

    /// 触发阈值：7 日日均净摄入比推荐量低这么多以上才提醒。
    /// 注意用的是**多日均值**而不是当日值 —— 否则某一天少吃了就弹告警，
    /// 正好违背「不对单日过度反应」。
    static let largeDeficitKcal: Double = 800

    struct Input: Sendable {
        var rdiKcal: Double
        var trend: TrendSnapshot
        var hasEnoughData: Bool
    }

    static func make(_ input: Input) -> AdviceItem? {
        guard input.hasEnoughData else { return nil }
        guard input.rdiKcal > 0 else { return nil }
        guard input.trend.daysWithExercise > 0 else { return nil }

        let t = input.trend
        let gapValue = input.rdiKcal - t.averageNetKcal
        guard gapValue > largeDeficitKcal else { return nil }

        let gap = AnalysisFormat.kcal(gapValue)

        return AdviceItem(
            category: .recovery,
            title: "净摄入缺口约 \(gap) kcal，恢复可能跟不上",
            detail: "最近 \(t.windowDays) 天净摄入日均 \(AnalysisFormat.kcal(t.averageNetKcal)) kcal，比推荐量低约 \(gap) kcal，同时有 \(t.daysWithExercise) 天运动记录。长期维持这么深的缺口，疲劳和掉肌肉的风险都会上升。",
            actionHint: "先把摄入提到接近推荐量，观察一两周的体感，不要继续往下压。")
    }
}

// MARK: - 建议生成：配置与记录

enum LoggingAdvice {

    static func noData() -> AdviceItem {
        AdviceItem(category: .logging,
                   title: "今天还没有记录",
                   detail: "先随手记一条就行，不用追求精确 —— 记了才能看出趋势，不记就永远只有猜测。",
                   actionHint: "试试在输入框里直接写：米饭一碗、番茄炒蛋、一杯牛奶")
    }

    static func insufficient(recordedDays: Int, required: Int) -> AdviceItem {
        let more = max(required - recordedDays, 1)
        return AdviceItem(category: .logging,
                          title: "再记 \(more) 天就能看趋势了",
                          detail: "目前只有 \(recordedDays) 天记录。单日数字波动很大，这时候下结论容易误判，看多日均值才有意义。",
                          actionHint: nil)
    }

    static func trendReminder() -> AdviceItem {
        AdviceItem(category: .logging,
                   title: "继续记录，趋势比单日数字更有意义",
                   detail: "估算本身就有误差，某一天偏高或偏低很正常。连续记满两周之后，趋势结论才真正可靠。",
                   actionHint: nil)
    }
}

enum ConfigAdvice {

    /// 双重计算提醒。用户把活动水平选得很高、又在 App 里记运动，消耗会被算两遍。
    static func doubleCounting(activityLevel: ActivityLevel, trend: TrendSnapshot) -> AdviceItem? {
        guard activityLevel.doubleCountRisk >= 0.6 else { return nil }
        guard trend.daysWithExercise >= 2 else { return nil }

        return AdviceItem(
            category: .logging,
            title: "「活动水平」可能和运动记录重复计算了",
            detail: "活动水平指的是工作和日常走动，不包含刻意锻炼。你选的是「\(activityLevel.displayName)」，而最近 \(trend.windowDays) 天有 \(trend.daysWithExercise) 天运动记录，日常消耗可能被算了两次，净摄入会被低估。",
            actionHint: "到设置页，按「不含锻炼的日常活动量」重新选一次。")
    }
}

// MARK: - 建议组装

enum AdviceComposer {

    struct Input: Sendable {
        var intake: Nutrition
        var burnKcal: Double
        var rdi: NutritionProfile
        var evaluations: [NutrientEvaluation]
        var trend: TrendSnapshot
        var energyBalance: DailyEnergyBalance
        var profile: UserProfileSnapshot
        var thresholds: AnalysisThresholds
        var hasEnoughData: Bool
        var maxCount: Int
    }

    static func build(_ input: Input) -> [AdviceItem] {
        var scored: [(priority: Int, item: AdviceItem)] = []

        func add(_ priority: Int, _ item: AdviceItem?) {
            if let item { scored.append((priority, item)) }
        }

        // 1) 完全没记录：只鼓励记录，不做任何营养结论
        if input.intake.isEmpty && input.burnKcal <= 0 {
            add(1, LoggingAdvice.noData())
            return finalize(scored, input: input)
        }

        let basis: EvaluationBasis = input.hasEnoughData
            ? .multiDay(input.trend.windowDays)
            : .singleDay

        // 2) 记录天数不足：先说清楚「别急着下结论」
        if !input.hasEnoughData {
            add(2, LoggingAdvice.insufficient(recordedDays: input.trend.recordedDays,
                                              required: input.thresholds.minimumDaysForConclusion))
        }

        // 3) 配置层面的双重计算风险
        add(3, ConfigAdvice.doubleCounting(activityLevel: input.profile.activityLevel,
                                           trend: input.trend))

        // 4) 缺口过大且还在运动
        add(4, DeficitRecoveryAdvice.make(DeficitRecoveryAdvice.Input(
            rdiKcal: input.rdi.kcal,
            trend: input.trend,
            hasEnoughData: input.hasEnoughData)))

        // 5) 微量营养素（通道 A：输入里没有运动数据）
        add(5, MicronutrientAdviceFactory.make(facts: input.microFacts))

        // 6) 蛋白质
        if let protein = input.evaluations.first(where: { $0.nutrient == .protein }) {
            add(6, ProteinAdviceFactory.make(ProteinAdviceFactory.Input(
                evaluation: protein,
                goal: input.profile.goal,
                weightKg: input.profile.weightKg)))
        }

        // 7) 能量（结合目标与多日趋势）
        add(7, EnergyAdviceFactory.make(EnergyAdviceFactory.Input(
            goal: input.profile.goal,
            rdiKcal: input.rdi.kcal,
            todayIntakeKcal: input.intake.kcal,
            todayBurnKcal: input.burnKcal,
            trend: input.trend,
            basis: basis,
            hasEnoughData: input.hasEnoughData)))

        // 8) 补水
        add(8, HydrationAdviceFactory.make(HydrationAdviceFactory.Input(
            todayBurnKcal: input.burnKcal)))

        // 9) 恢复 / 运动日碳水
        add(9, RecoveryAdviceFactory.make(RecoveryAdviceFactory.Input(
            todayBurnKcal: input.burnKcal,
            trend: input.trend)))

        return finalize(scored, input: input)
    }

    private static func finalize(_ scored: [(priority: Int, item: AdviceItem)],
                                 input: Input) -> [AdviceItem] {
        // 同优先级保持插入顺序，Swift 的 sorted 是稳定排序
        var result = scored.sorted { $0.priority < $1.priority }.map { $0.item }

        // 黑名单过滤：命中补偿性进食表述的建议直接丢弃，不改写、不软化
        result = result.filter { item in
            CompensationWordingGuard.isClean(item.title)
                && CompensationWordingGuard.isClean(item.detail)
                && CompensationWordingGuard.isClean(item.actionHint ?? "")
        }

        if result.count > input.maxCount {
            result = Array(result.prefix(input.maxCount))
        }

        // PRD 要求 2–3 条。候选不足时补兜底，最后按标题去重，
        // 避免兜底文案和已有条目说同一句话。
        if result.isEmpty { result.append(balanced(input: input)) }
        if result.count < 2 { result.append(LoggingAdvice.trendReminder()) }

        var seen = Set<String>()
        return result.filter { seen.insert($0.title).inserted }
    }

    private static func balanced(input: Input) -> AdviceItem {
        AdviceItem(
            category: .logging,
            title: input.hasEnoughData ? "各项指标基本都在推荐范围内" : "先记起来，趋势比单日数字更有用",
            detail: input.hasEnoughData
                ? "最近 \(input.trend.windowDays) 天看下来没有明显短板，保持现在的节奏就好。"
                : "估算本身有误差，某一天偏高偏低很正常。连续记满两周之后，趋势结论才真正可靠。",
            actionHint: nil)
    }
}

extension AdviceComposer.Input {

    /// 通道 A 的事实列表。**只带饮食数据**，没有 burnKcal。
    var microFacts: [MicronutrientAdviceFactory.Fact] {
        evaluations
            .filter { $0.nutrient.channel == .micronutrient }
            .map { MicronutrientAdviceFactory.Fact(nutrient: $0.nutrient,
                                                   actual: $0.actual,
                                                   assessedValue: $0.assessedValue,
                                                   basis: $0.basis,
                                                   target: $0.target,
                                                   status: $0.status) }
    }
}

// MARK: - 主引擎

struct DefaultAnalysisEngine: AnalysisEngine {

    /// 建议条数上限。PRD 要求 2–3 条。
    var maxAdviceCount: Int

    init(maxAdviceCount: Int = 3) {
        self.maxAdviceCount = max(maxAdviceCount, 1)
    }

    func analyze(_ context: AnalysisContext) -> DailyAnalysis {
        let rdi = context.rdi
        let thresholds = context.thresholds
        let windowDays = max(thresholds.trendWindowDays, 1)
        let trend = context.history.trendSnapshot(windowDays: windowDays)

        let recordedDays = trend.recordedDays
        let hasEnoughData = recordedDays >= thresholds.minimumDaysForConclusion
        let basis: EvaluationBasis = hasEnoughData ? .multiDay(windowDays) : .singleDay

        // 能量平衡只作描述性指标，不参与任何营养素判定
        let energyBalance = DailyEnergyBalance.make(intakeKcal: context.intake.kcal,
                                                    burnKcal: context.burnKcal,
                                                    rdiKcal: rdi.kcal)

        var evaluations: [NutrientEvaluation] = []
        evaluations.reserveCapacity(Nutrient.displayOrder.count)

        for nutrient in Nutrient.displayOrder {
            let todayValue = context.intake.value(for: nutrient)
            let target = rdi.value(for: nutrient)
            // 趋势优先：记录天数够时，用窗口均值判定，避免单日波动导致结论跳动
            let assessedValue = hasEnoughData ? trend.average(of: nutrient) : todayValue

            switch nutrient.channel {
            case .micronutrient:
                // 通道 A：输入里没有运动字段
                evaluations.append(MicronutrientJudge.evaluate(
                    MicronutrientJudge.Input(nutrient: nutrient,
                                             actual: todayValue,
                                             assessedValue: assessedValue,
                                             basis: basis,
                                             target: target),
                    thresholds: thresholds))

            case .energyMacro:
                evaluations.append(EnergyMacroJudge.evaluate(
                    EnergyMacroJudge.Input(nutrient: nutrient,
                                           actual: todayValue,
                                           assessedValue: assessedValue,
                                           basis: basis,
                                           target: target),
                    thresholds: thresholds))
            }
        }

        let advice = AdviceComposer.build(AdviceComposer.Input(
            intake: context.intake,
            burnKcal: context.burnKcal,
            rdi: rdi,
            evaluations: evaluations,
            trend: trend,
            energyBalance: energyBalance,
            profile: context.profile,
            thresholds: thresholds,
            hasEnoughData: hasEnoughData,
            maxCount: maxAdviceCount))

        return DailyAnalysis(dayIdentifier: context.dayIdentifier,
                             intake: context.intake,
                             target: rdi,
                             burnKcal: context.burnKcal,
                             energyBalance: energyBalance,
                             evaluations: evaluations,
                             advice: advice,
                             hasEnoughData: hasEnoughData,
                             recordedDays: recordedDays,
                             trendWindowDays: windowDays)
    }
}

// MARK: - 预览数据

/// 第 6 步 SwiftUI 预览用。造一份「记录到第 4 天、有运动」的上下文。
enum AnalysisPreviewData {

    static let profile = UserProfileSnapshot(sex: .male,
                                             age: 30,
                                             heightCm: 175,
                                             weightKg: 70,
                                             activityLevel: .light,
                                             goal: .cut)

    static var history: [DailySummary] {
        func day(_ id: String, kcal: Double, protein: Double, calcium: Double, fiber: Double, burn: Double) -> DailySummary {
            DailySummary(dayIdentifier: id,
                         intake: Nutrition(kcal: kcal, proteinG: protein, fatG: 55, carbsG: 220,
                                           calciumMG: calcium, ironMG: 11, vitaminCMG: 70, fiberG: fiber),
                         burnKcal: burn)
        }
        return [
            day("2026-10-17", kcal: 1750, protein: 82, calcium: 520, fiber: 16, burn: 0),
            day("2026-10-18", kcal: 1680, protein: 75, calcium: 480, fiber: 14, burn: 320),
            day("2026-10-19", kcal: 1810, protein: 88, calcium: 610, fiber: 18, burn: 0),
            day("2026-10-20", kcal: 1240, protein: 52, calcium: 330, fiber: 9,  burn: 420)
        ]
    }

    static var context: AnalysisContext {
        AnalysisContext(dayIdentifier: "2026-10-20",
                        intake: history[3].intake,
                        burnKcal: history[3].burnKcal,
                        profile: profile,
                        thresholds: .default,
                        history: history)
    }

    static var analysis: DailyAnalysis {
        DefaultAnalysisEngine().analyze(context)
    }
}
