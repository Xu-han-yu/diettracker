//
//  AnalysisSummaryCard.swift
//  DietTracker
//
//  今日分析摘要卡。
//
//  ⚠️ 结构上的双通道在这里显式呈现：
//     先「能量与宏量」（通道 B，看得到净能量与趋势），
//     再「微量营养素」（通道 A，明确告知与运动无关），
//     两段之间用分割线隔开，让用户一眼看出这是两套互不干扰的判断。
//

import SwiftUI

struct AnalysisSummaryCard: View {

    let analysis: DailyAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            DTSectionHeader(
                title: "今日分析",
                subtitle: analysis.hasEnoughData
                    ? "已记录 \(analysis.recordedDays) 天，按近 \(analysis.trendWindowDays) 天趋势判定"
                    : "仅 \(analysis.recordedDays) 天记录，以下结论偏参考",
                trailing: DayIdentifier.displayText(analysis.dayIdentifier))

            if !analysis.macroEvaluations.isEmpty {
                Text("能量与宏量")
                    .font(Tokens.Typography.overline)
                    .tracking(Tokens.Typography.overlineTracking)
                    .foregroundStyle(Tokens.Palette.textSecondary)
                VStack(spacing: Tokens.Space.sm) {
                    ForEach(analysis.macroEvaluations) { NutrientRow(evaluation: $0) }
                }
            }

            DTDivider()

            if !analysis.microEvaluations.isEmpty {
                Text("微量营养素")
                    .font(Tokens.Typography.overline)
                    .tracking(Tokens.Typography.overlineTracking)
                    .foregroundStyle(Tokens.Palette.textSecondary)
                VStack(spacing: Tokens.Space.sm) {
                    ForEach(analysis.microEvaluations) { NutrientRow(evaluation: $0) }
                }
                Text("这一段只看饮食摄入，与当天运动量无关 —— 运动再多也不会把「偏低」变成「充足」。")
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textTertiary)
            }

            DTDivider()

            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("明天可以这样调整")
                    .font(Tokens.Typography.headline)
                    .foregroundStyle(Tokens.Palette.textPrimary)
                ForEach(analysis.advice) { AdviceRow(item: $0) }
            }

            DTDisclaimer()
        }
        .dtCard()
    }
}

// MARK: - 单条建议

private struct AdviceRow: View {

    let item: AdviceItem

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            HStack(spacing: Tokens.Space.xs) {
                Text(item.category.displayName)
                    .font(Tokens.Typography.overline)
                    .tracking(Tokens.Typography.overlineTracking)
                    .foregroundStyle(Tokens.Palette.accentText)
                Spacer(minLength: 0)
            }
            Text(item.title)
                .font(Tokens.Typography.subhead)
                .foregroundStyle(Tokens.Palette.textPrimary)
            Text(item.detail)
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textSecondary)
            if let hint = item.actionHint {
                Text("明天试试：\(hint)")
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.accentText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dtSurfaceMuted()
    }
}

#Preview("分析摘要卡") {
    ScrollView {
        AnalysisSummaryCard(analysis: AnalysisPreviewData.analysis)
            .dtScreenPadding()
            .padding(.vertical, Tokens.Space.md)
    }
    .dtScreenBackground()
    .dtTheme(.default)
}
