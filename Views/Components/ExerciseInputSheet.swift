//
//  ExerciseInputSheet.swift
//  DietTracker
//
//  运动输入卡片：自然语言 → 解析预览（时长 / 强度可改）→ 保存。
//
//  ⚠️ 强度默认中等，用户可手动改低 / 中 / 高。
//     没匹配到具体运动时会用「中等强度一般运动」MET 兜底，
//     预览里必须明确标注，不能让用户以为是一个准确数字。
//

import SwiftUI
import SwiftData

struct ExerciseInputSheet: View {

    var dayIdentifier: String
    /// 估算用的体重。传 0 或未设置时用 ExerciseFallback.defaultWeightKg 兜底。
    var weightKg: Double
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var services

    @State private var rawText: String = ""
    @State private var drafts: [ExerciseDraft] = []
    @State private var hasParsed: Bool = false
    @State private var isSaving: Bool = false
    @State private var notice: String?

    private var writer: EntryWriter {
        EntryWriter(services: services, context: modelContext)
    }

    private var totalKcal: Double {
        drafts.reduce(0) { $0 + writer.estimate(draft: $1, weightKg: weightKg).kcal }
    }

    private var resolvedWeightText: String {
        weightKg > 0
            ? "按体重 \(AnalysisFormat.kcal(weightKg)) kg 估算"
            : "未设置体重，按 \(AnalysisFormat.kcal(ExerciseFallback.defaultWeightKg)) kg 估算"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.md) {
                    inputEditor
                    if hasParsed { previewSection }
                    if let notice {
                        Text(notice)
                            .font(Tokens.Typography.caption)
                            .foregroundStyle(Tokens.Palette.textSecondary)
                    }
                    DTDisclaimer()
                }
                .dtScreenPadding()
                .padding(.vertical, Tokens.Space.md)
            }
            .dtScreenBackground()
            .navigationTitle("记一笔运动")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text(isSaving ? "保存中…" : "保存")
                    }
                    .disabled(drafts.isEmpty || isSaving)
                }
            }
        }
    }

    // MARK: 子视图

    private var inputEditor: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            TextField("例如：跑步 30 分钟、力量训练 40 分钟", text: $rawText, axis: .vertical)
                .lineLimit(2...5)
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Palette.textPrimary)
                .padding(Tokens.Space.sm)
                .background(Tokens.Palette.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                .dtMaxDynamicType()

            Button { runParse() } label: { Text("解析") }
                .dtSecondaryButton()
                .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            DTSectionHeader(title: "识别结果",
                            subtitle: resolvedWeightText,
                            trailing: "合计 \(AnalysisFormat.kcal(totalKcal)) kcal")

            if drafts.isEmpty {
                Text("没能识别出运动。试试写成「跑步 30 分钟」这样的形式，或者直接写运动名再手动填时长。")
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textSecondary)
            } else {
                ForEach(drafts.indices, id: \.self) { index in
                    draftRow(index: index, draft: drafts[index])
                    if index < drafts.count - 1 { DTDivider() }
                }
            }

            Text("消耗 = MET × 体重 kg × 小时数。这是按群体平均值推算的估算值，个体差异很大。")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
        .dtCard()
    }

    private func draftRow(index: Int, draft: ExerciseDraft) -> some View {
        let estimate = writer.estimate(draft: draft, weightKg: weightKg)
        return VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                Text(draft.name)
                    .font(Tokens.Typography.subhead)
                    .foregroundStyle(Tokens.Palette.textPrimary)
                Spacer(minLength: Tokens.Space.xxs)
                Text("\(AnalysisFormat.kcal(estimate.kcal)) kcal")
                    .dtNumber(Tokens.Typography.Number.small)
            }

            Stepper(value: $drafts[index].minutes,
                    in: 0...ExerciseFallback.maxMinutes,
                    step: 5) {
                Text("时长 \(Int(drafts[index].minutes.rounded())) 分钟")
                    .font(Tokens.Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Palette.textSecondary)
            }
            .dtMaxDynamicType()

            Picker("强度", selection: $drafts[index].intensity) {
                ForEach(ExerciseIntensity.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("\(estimate.formulaText) ≈ \(AnalysisFormat.kcal(estimate.kcal)) kcal")
                .font(Tokens.Typography.overline)
                .monospacedDigit()
                .foregroundStyle(Tokens.Palette.textTertiary)

            if let caution = estimate.cautionText {
                Text(caution)
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 动作

    private func runParse() {
        drafts = writer.previewExercises(rawText: rawText)
        hasParsed = true
        notice = nil
    }

    @MainActor
    private func save() {
        isSaving = true
        defer { isSaving = false }

        let entry = writer.saveExercise(dayIdentifier: dayIdentifier,
                                        rawText: rawText,
                                        weightKg: weightKg,
                                        drafts: drafts)
        if entry == nil {
            notice = "没有可保存的内容，先点「解析」看看识别结果。"
            return
        }
        onSaved?()
        dismiss()
    }
}

#Preview("运动输入") {
    ExerciseInputPreviewHost()
        .dtTheme(.default)
}

/// 预览宿主：注入一个内存 ModelContext，否则点「解析」时会因为取不到 context 崩。
@MainActor
private struct ExerciseInputPreviewHost: View {
    private let context = try! SeedData.makePreviewContext()

    var body: some View {
        ExerciseInputSheet(dayIdentifier: DayIdentifier.today, weightKg: 70)
            .modelContext(context)
    }
}
