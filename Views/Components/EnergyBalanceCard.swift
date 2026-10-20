//
//  EnergyBalanceCard.swift
//  DietTracker
//
//  今日净能量卡片。首页唯一的 40pt hero 数字。
//
//  ⚠️ 净摄入是**描述性指标**，不是判定指标。
//     判定主线恒为「摄入 vs RDI」，运动消耗只出现在这里，永远不回加进 RDI。
//

import SwiftUI

struct EnergyBalanceCard: View {

    var intakeKcal: Double
    var burnKcal: Double
    var rdiKcal: Double
    var balance: DailyEnergyBalance

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            DTSectionHeader(title: "今日净摄入",
                            subtitle: "摄入 − 运动消耗",
                            trailing: balance.status.displayName)

            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                Text(AnalysisFormat.kcal(balance.netKcal))
                    .dtNumber(Tokens.Typography.Number.hero)
                Text("kcal")
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textTertiary)
                Spacer(minLength: 0)
            }

            HStack(spacing: Tokens.Space.xs) {
                DTMetric(label: "摄入", value: intakeKcal, unit: "kcal")
                DTMetric(label: "运动", value: burnKcal, unit: "kcal")
                DTMetric(label: "推荐", value: rdiKcal, unit: "kcal", emphasized: true)
            }

            if !balance.note.isEmpty {
                Text(balance.note)
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textSecondary)
            }

            DTDivider()

            Text("运动消耗只影响这里的净摄入与能量建议，不会改变任何营养素是否达标的判定。")
                .font(Tokens.Typography.overline)
                .foregroundStyle(Tokens.Palette.textTertiary)

            DTDisclaimer()
        }
        .dtCard()
    }
}

#Preview("净能量卡片 · 浅色") {
    EnergyBalanceCard(intakeKcal: 1824,
                      burnKcal: 540,
                      rdiKcal: 1813,
                      balance: DailyEnergyBalance.make(intakeKcal: 1824, burnKcal: 540, rdiKcal: 1813))
        .dtScreenPadding()
        .dtScreenBackground()
        .dtTheme(.default)
        .preferredColorScheme(.light)
}

#Preview("净能量卡片 · 深色") {
    EnergyBalanceCard(intakeKcal: 1824,
                      burnKcal: 540,
                      rdiKcal: 1813,
                      balance: DailyEnergyBalance.make(intakeKcal: 1824, burnKcal: 540, rdiKcal: 1813))
        .dtScreenPadding()
        .dtScreenBackground()
        .dtTheme(.default)
        .preferredColorScheme(.dark)
}
