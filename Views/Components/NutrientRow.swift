//
//  NutrientRow.swift
//  DietTracker
//
//  一条营养素的判定行：名称 + 状态 + 当日值 / 目标值 + 进度条 + 判定口径。
//
//  ⚠️ 右上角的百分比用的是**判定值**（数据充足时为近 N 日均值），
//     第二行展示的是当日实际值。两者不一致是设计使然，
//     「判定口径」那一行小字就是用来说明这件事的。
//

import SwiftUI

struct NutrientRow: View {

    let evaluation: NutrientEvaluation
    /// 是否展示「判定口径」小字。列表里每行都展示会太吵，默认关。
    var showsBasis: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            HStack(alignment: .center, spacing: Tokens.Space.xs) {
                Text(evaluation.nutrient.displayName)
                    .font(Tokens.Typography.subhead)
                    .foregroundStyle(Tokens.Palette.textPrimary)
                Spacer(minLength: Tokens.Space.xxs)
                DTStatusChip(text: evaluation.status.displayName, status: evaluation.status)
            }

            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                Text(evaluation.valueText)
                    .font(Tokens.Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Palette.textSecondary)
                Spacer(minLength: Tokens.Space.xxs)
                Text(evaluation.percentText)
                    .font(Tokens.Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Palette.textTertiary)
            }

            ProgressView(value: clampedRatio)
                .tint(evaluation.status.dtColor)

            if showsBasis {
                Text("按\(evaluation.basis.label)判定 · \(evaluation.assessedText)")
                    .font(Tokens.Typography.overline)
                    .foregroundStyle(Tokens.Palette.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 进度条封顶 100%，否则「偏高」的行会把条撑满到看不出差别。
    private var clampedRatio: Double {
        min(max(evaluation.ratio, 0), 1)
    }
}

#Preview("营养判定行") {
    VStack(spacing: Tokens.Space.md) {
        NutrientRow(evaluation: AnalysisPreviewData.analysis.evaluations[0], showsBasis: true)
        NutrientRow(evaluation: AnalysisPreviewData.analysis.evaluations[4], showsBasis: true)
    }
    .dtScreenPadding()
    .padding(Tokens.Space.md)
    .dtCard()
    .dtScreenBackground()
    .dtTheme(.default)
}
