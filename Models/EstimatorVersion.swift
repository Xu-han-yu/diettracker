//
//  EstimatorVersion.swift
//  DietTracker
//
//  估算算法版本号。所有「估算快照」都要冗余存一份版本号，
//  这样将来改算法时，能分辨某条历史记录是用哪版算法算出来的，
//  也保证改体重 / 改算法都不会篡改已有历史（可复现性验收项）。
//

import Foundation

enum EstimatorVersion {
    /// 食物份量与营养估算（本地词典 + 规则）
    static let food = "food-local-v1"
    /// 运动消耗估算（MET 公式）
    static let exerciseMET = "exercise-met-v1"
    /// 推荐摄入量 RDI（Mifflin-St Jeor + 活动系数 + 目标调整）
    static let rdi = "rdi-mifflin-v1"
    /// 分析引擎（双通道 + 阈值 + 建议生成）
    static let analysis = "analysis-v1"
}
