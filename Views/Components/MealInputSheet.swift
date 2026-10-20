//
//  MealInputSheet.swift
//  DietTracker
//
//  饮食输入卡片：自然语言 → 解析预览（可人工核对）→ 保存。
//
//  ⚠️ 解析结果永远是「可修正的猜测」：
//     预览阶段必须让用户看到识别出了什么、估了多少克，确认后才落库。
//

import SwiftUI
import SwiftData

struct MealInputSheet: View {

    var slots: [MealSlot]
    var dayIdentifier: String
    var initialSlotID: String?
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var services

    @State private var rawText: String = ""
    @State private var selectedSlotID: String = ""
    @State private var parsed: [ParsedFood] = []
    @State private var unmatched: [String] = []
    @State private var hasParsed: Bool = false
    @State private var isSaving: Bool = false
    @State private var notice: String?

    private var writer: EntryWriter {
        EntryWriter(services: services, context: modelContext)
    }

    private var currentSlot: MealSlot? {
        slots.first { $0.slotID == selectedSlotID }
    }

    private var canSave: Bool {
        !parsed.isEmpty && currentSlot != nil && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.md) {
                    slotPicker
                    inputEditor
                    if hasParsed { previewSection }
                    if let notice { Text(notice).font(Tokens.Typography.caption).foregroundStyle(Tokens.Palette.textSecondary) }
                    DTDisclaimer()
                }
                .dtScreenPadding()
                .padding(.vertical, Tokens.Space.md)
            }
            .dtScreenBackground()
            .navigationTitle("记一笔饮食")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        Text(isSaving ? "保存中…" : "保存")
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if selectedSlotID.isEmpty {
                    selectedSlotID = initialSlotID ?? slots.first?.slotID ?? ""
                }
            }
        }
    }

    // MARK: 子视图

    private var slotPicker: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text("时段")
                .font(Tokens.Typography.overline)
                .tracking(Tokens.Typography.overlineTracking)
                .foregroundStyle(Tokens.Palette.textSecondary)
            // 默认 7 个时段，用分段控件会挤成一团，改用菜单样式
            Picker("时段", selection: $selectedSlotID) {
                ForEach(slots) { slot in
                    Text(slot.name).tag(slot.slotID)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Tokens.Palette.accent)
        }
    }

    private var inputEditor: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            TextField("例如：米饭一碗、番茄炒蛋、一杯牛奶", text: $rawText, axis: .vertical)
                .lineLimit(2...5)
                .font(Tokens.Typography.body)
                .foregroundStyle(Tokens.Palette.textPrimary)
                .padding(Tokens.Space.sm)
                .background(Tokens.Palette.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                .dtMaxDynamicType()

            Button {
                runParse()
            } label: {
                Text("解析")
            }
            .dtSecondaryButton()
            .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            DTSectionHeader(title: "识别结果",
                            subtitle: "共 \(parsed.count) 项，保存前可以再核对",
                            trailing: nil)

            if parsed.isEmpty {
                Text("没能识别出食物。可以换个说法试试，比如把「吃了点东西」写成具体的菜名和份量。")
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textSecondary)
            } else {
                ForEach(parsed.indices, id: \.self) { index in
                    parsedRow(parsed[index])
                }
            }

            if !unmatched.isEmpty {
                Text("没认出来的片段：\(unmatched.joined(separator: "、"))")
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textTertiary)
            }
        }
        .dtCard()
    }

    private func parsedRow(_ item: ParsedFood) -> some View {
        let quick = writer.quickNutrition(for: item)
        return HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                Text(item.name)
                    .font(Tokens.Typography.subhead)
                    .foregroundStyle(Tokens.Palette.textPrimary)
                Text(portionText(item))
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textSecondary)
            }
            Spacer(minLength: Tokens.Space.xxs)
            Text("\(AnalysisFormat.kcal(quick.nutrition.kcal)) kcal")
                .font(Tokens.Typography.caption)
                .monospacedDigit()
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
    }

    private func portionText(_ item: ParsedFood) -> String {
        var parts: [String] = []
        if let q = item.quantityText, !q.isEmpty { parts.append(q) }
        if let g = item.grams, g > 0 { parts.append("约 \(AnalysisFormat.kcal(g)) g") }
        if parts.isEmpty { parts.append("按默认份量估算") }
        return parts.joined(separator: " · ")
    }

    // MARK: 动作

    private func runParse() {
        let result = writer.previewFoods(rawText: rawText)
        parsed = result.items
        unmatched = result.unmatchedSegments
        hasParsed = true
        notice = nil
    }

    @MainActor
    private func save() async {
        guard let slot = currentSlot else { return }
        isSaving = true
        defer { isSaving = false }

        let entry = await writer.saveMeal(dayIdentifier: dayIdentifier,
                                          slot: slot,
                                          rawText: rawText)
        if entry == nil {
            notice = "没有可保存的内容，先点「解析」看看识别结果。"
            return
        }
        onSaved?()
        dismiss()
    }
}

#Preview("饮食输入") {
    MealInputPreviewHost()
        .dtTheme(.default)
}

/// 预览宿主。标 @MainActor 是为了让 `makePreviewContext()` 在正确的隔离域里调用，
/// 否则云端编译会因为「在非隔离上下文中调用 main actor 方法」直接报错。
@MainActor
private struct MealInputPreviewHost: View {
    private let context = try! SeedData.makePreviewContext()

    var body: some View {
        let slots = (try? context.fetch(FetchDescriptor<MealSlot>())) ?? []
        return MealInputSheet(slots: slots, dayIdentifier: DayIdentifier.today)
            .modelContext(context)
    }
}
