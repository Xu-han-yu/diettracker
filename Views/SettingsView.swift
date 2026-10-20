//
//  SettingsView.swift
//  DietTracker
//
//  设置页：个人档案 → RDI 预览 → 判定阈值 → 时段管理 → 数据导出 → 关于。
//
//  ⚠️ 两处文案是硬约束，不要删改：
//   1. 活动水平的 guidance —— 它是防止「运动消耗被算两遍」的第一道防线。
//   2. 体重的用途说明 —— MET 公式与蛋白质目标都依赖它。
//

import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserProfile]
    @Query(sort: \MealSlot.sortOrder) private var slots: [MealSlot]
    @Query(sort: \MealEntry.timestamp) private var meals: [MealEntry]
    @Query(sort: \ExerciseEntry.timestamp) private var exercises: [ExerciseEntry]

    @State private var exportText: String = ""
    @State private var showingShare = false
    @State private var showingClearConfirm = false
    @State private var newSlotName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                if let profile = profiles.first {
                    ProfileSection(profile: profile)
                    RDISection(profile: profile)
                    ThresholdSection(profile: profile)
                } else {
                    Section {
                        Text("档案还在初始化，稍等一下。")
                            .font(Tokens.Typography.body)
                            .foregroundStyle(Tokens.Palette.textSecondary)
                    }
                    .listRowBackground(Tokens.Palette.surface)
                }

                slotSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .dtScreenBackground()
            .navigationTitle("设置")
            .sheet(isPresented: $showingShare) {
                ShareSheet(text: exportText)
            }
            .confirmationDialog("清空全部记录？", isPresented: $showingClearConfirm, titleVisibility: .visible) {
                Button("清空", role: .destructive) { clearAll() }
                Button("取消", role: .cancel) { }
            } message: {
                Text("会删除全部饮食与运动记录，个人档案和时段设置保留。建议先导出一份。")
            }
        }
    }

    // MARK: 时段管理

    private var slotSection: some View {
        Section {
            ForEach(slots) { slot in
                SlotRow(slot: slot) {
                    modelContext.delete(slot)
                    try? modelContext.save()
                }
                .listRowBackground(Tokens.Palette.surface)
            }

            HStack(spacing: Tokens.Space.xs) {
                TextField("新时段名称", text: $newSlotName)
                    .font(Tokens.Typography.body)
                Button {
                    addSlot()
                } label: {
                    Text("添加")
                        .font(Tokens.Typography.subhead)
                        .foregroundStyle(Tokens.Palette.accentText)
                }
                .disabled(newSlotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .listRowBackground(Tokens.Palette.surface)
        } header: {
            Text("进食时段")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textSecondary)
        } footer: {
            Text("改名不会影响历史记录 —— 每条饮食都存了当时的时段名快照。")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
    }

    // MARK: 数据

    private var dataSection: some View {
        Section {
            Button {
                exportText = makeExportJSON()
                showingShare = true
            } label: {
                Text("导出全部记录（JSON）")
                    .font(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Palette.accentText)
            }
            .listRowBackground(Tokens.Palette.surface)

            Button(role: .destructive) {
                showingClearConfirm = true
            } label: {
                Text("清空全部记录")
                    .font(Tokens.Typography.body)
            }
            .listRowBackground(Tokens.Palette.surface)
        } header: {
            Text("数据")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textSecondary)
        } footer: {
            Text("数据只存在本机，没有账号、不上传。卸载 App 会一并删除，重装前记得导出。")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
    }

    // MARK: 关于

    private var aboutSection: some View {
        Section {
            HStack {
                Text("版本")
                    .font(Tokens.Typography.body)
                Spacer(minLength: Tokens.Space.xs)
                Text(appVersion)
                    .font(Tokens.Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Palette.textTertiary)
            }
            .listRowBackground(Tokens.Palette.surface)

            HStack {
                Text("在线营养数据")
                    .font(Tokens.Typography.body)
                Spacer(minLength: Tokens.Space.xs)
                Text(NutritionAPIConfig.isEnabled ? "已启用（可选增强）" : "未配置，纯本地运行")
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textTertiary)
            }
            .listRowBackground(Tokens.Palette.surface)

            DTDisclaimer()
                .listRowBackground(Tokens.Palette.surface)
        } header: {
            Text("关于")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textSecondary)
        } footer: {
            Text("所有数字都来自本地食物表与 MET 表的估算，不接入 HealthKit / Apple Watch，也不做联网请求（除非你配置了在线营养数据）。")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
    }

    // MARK: 动作

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func addSlot() {
        let name = newSlotName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let nextOrder = (slots.map { $0.sortOrder }.max() ?? -1) + 1
        let slot = MealSlot(slotID: UUID().uuidString,
                            name: name,
                            sortOrder: nextOrder,
                            hourOfDay: 12,
                            isEnabled: true,
                            isCustom: true)
        modelContext.insert(slot)
        try? modelContext.save()
        newSlotName = ""
    }

    private func clearAll() {
        try? modelContext.delete(model: MealEntry.self)
        try? modelContext.delete(model: ExerciseEntry.self)
        try? modelContext.delete(model: WaterEntry.self)
        try? modelContext.save()
    }

    // MARK: 导出

    private func makeExportJSON() -> String {
        let payload = ExportPayload(
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            profile: profiles.first.map { ExportProfile(profile: $0) },
            meals: meals.map { ExportMeal(entry: $0) },
            exercises: exercises.map { ExportExercise(entry: $0) }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload),
              let text = String(data: data, encoding: .utf8) else {
            return "导出失败：数据无法序列化。"
        }
        return text
    }
}

// MARK: - 档案

private struct ProfileSection: View {

    @Bindable var profile: UserProfile

    var body: some View {
        Section {
            Picker("性别", selection: $profile.sexRaw) {
                ForEach(Sex.allCases) { Text($0.displayName).tag($0.rawValue) }
            }
            .listRowBackground(Tokens.Palette.surface)

            numberRow("年龄", value: $profile.age, suffix: "岁")
            numberRow("身高", value: $profile.heightCm, suffix: "cm")
            numberRow("体重", value: $profile.weightKg, suffix: "kg")

            Picker("活动水平", selection: $profile.activityLevelRaw) {
                ForEach(ActivityLevel.allCases) { Text($0.displayName).tag($0.rawValue) }
            }
            .listRowBackground(Tokens.Palette.surface)

            Picker("目标", selection: $profile.goalRaw) {
                ForEach(Goal.allCases) { Text($0.displayName).tag($0.rawValue) }
            }
            .listRowBackground(Tokens.Palette.surface)
        } header: {
            Text("个人档案")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textSecondary)
        } footer: {
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                Text(profile.activityLevel.guidance)
                Text("体重用于运动消耗的 MET 计算和蛋白质目标，请填写；留 0 时按 \(AnalysisFormat.kcal(ExerciseFallback.defaultWeightKg)) kg 估算。")
            }
            .font(Tokens.Typography.caption)
            .foregroundStyle(Tokens.Palette.textTertiary)
        }
    }

    private func numberRow(_ title: String,
                           value: Binding<Double>,
                           suffix: String) -> some View {
        HStack(spacing: Tokens.Space.xs) {
            Text(title)
                .font(Tokens.Typography.body)
            Spacer(minLength: Tokens.Space.xs)
            TextField(title, value: value, format: .number)
                .font(Tokens.Typography.body)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 88)
            Text(suffix)
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
        .listRowBackground(Tokens.Palette.surface)
    }

    private func numberRow(_ title: String,
                           value: Binding<Int>,
                           suffix: String) -> some View {
        HStack(spacing: Tokens.Space.xs) {
            Text(title)
                .font(Tokens.Typography.body)
            Spacer(minLength: Tokens.Space.xs)
            TextField(title, value: value, format: .number)
                .font(Tokens.Typography.body)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .frame(width: 88)
            Text(suffix)
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
        .listRowBackground(Tokens.Palette.surface)
    }
}

// MARK: - RDI 预览

private struct RDISection: View {

    let profile: UserProfile

    private var rdi: NutritionProfile { profile.rdi }

    var body: some View {
        Section {
            rdiRow("每日推荐热量", value: rdi.kcal, unit: "kcal")
            rdiRow("蛋白质", value: rdi.proteinG, unit: "g")
            rdiRow("脂肪", value: rdi.fatG, unit: "g")
            rdiRow("碳水化合物", value: rdi.carbsG, unit: "g")
            rdiRow("钙", value: rdi.calciumMG, unit: "mg")
            rdiRow("铁", value: rdi.ironMG, unit: "mg")
            rdiRow("维生素 C", value: rdi.vitaminCMG, unit: "mg")
            rdiRow("膳食纤维", value: rdi.fiberG, unit: "g")
        } header: {
            Text("推荐摄入量（RDI）")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textSecondary)
        } footer: {
            Text("BMR 用 Mifflin-St Jeor 估算，乘以活动系数后再按目标调整（维持 100% / 减脂 80% / 增肌 110%）。RDI 不含运动回加 —— 运动只在净能量里体现。")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
    }

    private func rdiRow(_ title: String, value: Double, unit: String) -> some View {
        HStack(spacing: Tokens.Space.xs) {
            Text(title)
                .font(Tokens.Typography.body)
            Spacer(minLength: Tokens.Space.xs)
            Text("\(AnalysisFormat.kcal(value)) \(unit)")
                .font(Tokens.Typography.caption)
                .monospacedDigit()
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
        .listRowBackground(Tokens.Palette.surface)
    }
}

// MARK: - 阈值

private struct ThresholdSection: View {

    @Bindable var profile: UserProfile

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                Text("偏低阈值 \(Int((profile.lowRatioThreshold * 100).rounded()))%")
                    .font(Tokens.Typography.body)
                Slider(value: $profile.lowRatioThreshold, in: 0.50...0.90, step: 0.05)
                    .tint(Tokens.Palette.accent)
            }
            .listRowBackground(Tokens.Palette.surface)

            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                Text("偏高阈值 \(Int((profile.highRatioThreshold * 100).rounded()))%")
                    .font(Tokens.Typography.body)
                Slider(value: $profile.highRatioThreshold, in: 1.10...1.60, step: 0.05)
                    .tint(Tokens.Palette.accent)
            }
            .listRowBackground(Tokens.Palette.surface)

            Stepper(value: $profile.minimumDaysForConclusion, in: 1...7) {
                Text("至少 \(profile.minimumDaysForConclusion) 天记录才下结论")
                    .font(Tokens.Typography.body)
            }
            .listRowBackground(Tokens.Palette.surface)

            Stepper(value: $profile.trendWindowDays, in: 3...30) {
                Text("趋势窗口 \(profile.trendWindowDays) 天")
                    .font(Tokens.Typography.body)
            }
            .listRowBackground(Tokens.Palette.surface)
        } header: {
            Text("判定阈值")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textSecondary)
        } footer: {
            Text("阈值只作用于「摄入 vs RDI」的比值，不随运动量变化。趋势窗口越大，结论越稳，但对近期变化的反应也越慢。")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
    }
}

// MARK: - 时段行

private struct SlotRow: View {

    @Bindable var slot: MealSlot
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            TextField("时段名称", text: $slot.name)
                .font(Tokens.Typography.body)
            Toggle("", isOn: $slot.isEnabled)
                .labelsHidden()
                .tint(Tokens.Palette.accent)
            if slot.isCustom {
                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }
}

// MARK: - 分享

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        // iPad 上必须给 popover 一个 sourceView，否则直接崩溃。
        // 工程支持 1,2 两种设备族，这里用一个游离 UIView 兜住。
        if let popover = controller.popoverPresentationController {
            popover.sourceView = context.coordinator.anchorView
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    final class Coordinator {
        let anchorView = UIView()
    }
}

// MARK: - 导出模型

private struct ExportPayload: Codable {
    var exportedAt: String
    var profile: ExportProfile?
    var meals: [ExportMeal]
    var exercises: [ExportExercise]
}

private struct ExportProfile: Codable {
    var sex: String
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var activityLevel: String
    var goal: String
    var rdiKcal: Double

    init(profile: UserProfile) {
        sex = profile.sex.rawValue
        age = profile.age
        heightCm = profile.heightCm
        weightKg = profile.weightKg
        activityLevel = profile.activityLevel.rawValue
        goal = profile.goal.rawValue
        rdiKcal = profile.rdi.kcal
    }
}

private struct ExportMeal: Codable {
    var dayIdentifier: String
    var timestamp: String
    var slotName: String
    var rawText: String
    var kcal: Double
    var items: [ExportFoodItem]

    init(entry: MealEntry) {
        dayIdentifier = entry.dayIdentifier
        timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        slotName = entry.slotName
        rawText = entry.rawText
        kcal = entry.totalKcal
        items = entry.items.map { ExportFoodItem(item: $0) }
    }
}

private struct ExportFoodItem: Codable {
    var name: String
    var grams: Double
    var kcal: Double
    var proteinG: Double
    var fatG: Double
    var carbsG: Double
    var source: String

    init(item: FoodItem) {
        name = item.name
        grams = item.grams
        kcal = item.kcal
        proteinG = item.proteinG
        fatG = item.fatG
        carbsG = item.carbsG
        source = item.source.rawValue
    }
}

private struct ExportExercise: Codable {
    var dayIdentifier: String
    var timestamp: String
    var rawText: String
    var kcal: Double
    var items: [ExportExerciseItem]

    init(entry: ExerciseEntry) {
        dayIdentifier = entry.dayIdentifier
        timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        rawText = entry.rawText
        kcal = entry.totalKcal
        items = entry.items.map { ExportExerciseItem(item: $0) }
    }
}

private struct ExportExerciseItem: Codable {
    var name: String
    var minutes: Double
    var intensity: String
    var metValue: Double
    var estimatedKcal: Double
    var weightKgAtEstimate: Double
    var isFallback: Bool

    init(item: ExerciseItem) {
        name = item.name
        minutes = item.minutes
        intensity = item.intensity.rawValue
        metValue = item.metValue
        estimatedKcal = item.estimatedKcal
        weightKgAtEstimate = item.weightKgAtEstimate
        isFallback = item.isFallback
    }
}

#Preview("设置页") {
    SettingsViewPreviewHost()
        .dtTheme(.default)
}

@MainActor
private struct SettingsViewPreviewHost: View {
    private let context = try! SeedData.makePreviewContext()

    var body: some View {
        SettingsView()
            .modelContext(context)
    }
}
