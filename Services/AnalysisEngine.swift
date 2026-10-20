//
//  AnalysisEngine.swift
//  DietTracker
//
//  分析引擎协议。**实现在第 5 步给出（DefaultAnalysisEngine）。**
//
//  三条不可动摇的规则：
//   1. 判定以「摄入 vs RDI」为主线，运动消耗**不回加**到 RDI。
//   2. 双通道物理隔离：
//        通道 A（钙/铁/维C/纤维）的求值函数**在签名上就拿不到 burnKcal**；
//        通道 B（热量/蛋白/脂肪/碳水）才读净能量与 7 天趋势。
//        B 无权修改 A 的状态。
//   3. 建议文案禁止出现「因为运动了所以可以多吃 / 补回来 / 奖励自己」这类
//      补偿性进食表述（第 5 步用黑名单 guard 实现）。
//

import Foundation

/// 分析上下文。全部是值类型，便于单测与跨线程调用。
struct AnalysisContext: Sendable {
    /// 目标日期（yyyy-MM-dd）
    var dayIdentifier: String
    /// 当日饮食摄入聚合
    var intake: Nutrition
    /// 当日刻意锻炼消耗（MET 估算）
    var burnKcal: Double
    /// 用户档案快照
    var profile: UserProfileSnapshot
    /// 判定阈值
    var thresholds: AnalysisThresholds
    /// 历史窗口数据（含目标日），按 dayIdentifier 升序
    var history: [DailySummary]

    init(dayIdentifier: String,
         intake: Nutrition,
         burnKcal: Double = 0,
         profile: UserProfileSnapshot = .placeholder,
         thresholds: AnalysisThresholds = .default,
         history: [DailySummary] = []) {
        self.dayIdentifier = dayIdentifier
        self.intake = intake
        self.burnKcal = burnKcal
        self.profile = profile
        self.thresholds = thresholds
        self.history = history
    }

    /// 推荐摄入量（不含运动回加）
    var rdi: NutritionProfile { NutritionProfile.compute(from: profile) }

    /// 窗口内有记录的天数
    var recordedDays: Int { history.filter { $0.hasData }.count }

    /// 是否有足够天数下结论
    var hasEnoughData: Bool { recordedDays >= thresholds.minimumDaysForConclusion }
}

protocol AnalysisEngine {
    /// 纯函数：同样输入必定得到同样输出。不读写数据库、不做网络请求。
    func analyze(_ context: AnalysisContext) -> DailyAnalysis
}

// MARK: - 补偿性进食文案黑名单

/// 建议文案里**绝不许出现**的片段。第 5 步在生成建议后统一过滤。
enum CompensationWordingGuard {

    static let bannedPhrases: [String] = [
        "可以多吃", "多吃点", "补回来", "吃回去", "奖励自己",
        "今天可以放松", "放纵一下", "消耗了所以", "运动了所以",
        "抵消", "不怕多吃", "随便吃"
    ]

    /// 命中黑名单返回具体片段，未命中返回 nil。
    static func violation(in text: String) -> String? {
        bannedPhrases.first { text.contains($0) }
    }

    static func isClean(_ text: String) -> Bool { violation(in: text) == nil }
}
