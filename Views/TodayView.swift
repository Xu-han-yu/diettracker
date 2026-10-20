//
//  TodayView.swift
//  DietTracker
//
//  今日页：一张干净的数据仪表盘。
//
//  结构（从上到下）：
//   1. 净摄入 hero（40pt，全页唯一视觉锚点）
//   2.「分析今天」按钮 + 分析摘要卡
//   3. 按进食时段分组的饮食记录
//   4. 今日运动
//   5. 今日饮水
//
//  所有配色 / 字号 / 间距一律走 Tokens 与 dtXxx 修饰符，本文件不出现任何字面量。
//

import SwiftUI
import SwiftData

struct TodayView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var services
    @Environment(\.dtTheme) private var theme

    @Query(sort: \MealSlot.sortOrder) private var slots: [MealSlot]
    @Query(sort: \MealEntry.timestamp) private var meals: [MealEntry]
    @Query(sort: \ExerciseEntry.timestamp) private var exercises: [ExerciseEntry]
    @Query(sort: \WaterEntry.timestamp) private var waters: [WaterEntry]
    @Query private var profiles: [UserProfile]

    @State private var analysis: DailyAnalysis?
    @State private var showingMealInput = false
    @State private var showingExerciseInput = false
    @State private var inputSlotID: String? = nil

    // MARK: 派生数据

    private var dayID: String { DayIdentifier.today }

    private var profile: UserProfile { profiles.first ?? UserProfile() }

    private var rdi: NutritionProfile { profile.rdi }

    private var enabledSlots: [MealSlot] {
        slots.filter { $0.isEnabled }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var todayMeals: [MealEntry] { meals.filter { $0.dayIdentifier == dayID } }
    private var todayExercises: [ExerciseEntry] { exercises.filter { $0.dayIdentifier == dayID } }
    private var todayWaters: [WaterEntry] { waters.filter { $0.dayIdentifier == dayID } }

    private var todayIntake: DailyIntake { DayAggregator.intake(dayIdentifier: dayID, from: meals) }
    private var todayBurn: Double { DayAggregator.burnKcal(dayIdentifier: dayID, from: exercises) }
    private var waterTotalML: Double { todayWaters.reduce(0) { $0 + $1.amountML } }

    private var energyBalance: DailyEnergyBalance {
        DailyEnergyBalance.make(intakeKcal: todayIntake.nutrition.kcal,
                                burnKcal: todayBurn,
                                rdiKcal: rdi.kcal)
    }

    /// 未归到任何已启用时段的记录（时段被停用后会出现）
    private var orphanMeals: [MealEntry] {
        let ids = Set(enabledSlots.map { $0.slotID })
        return todayMeals.filter { !ids.contains($0.slotID) }
    }

    // MARK: 主体

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.cardSpacing) {
                    EnergyBalanceCard(intakeKcal: todayIntake.nutrition.kcal,
                                      burnKcal: todayBurn,
                                      rdiKcal: rdi.kcal,
                                      balance: energyBalance)

                    Button { runAnalysis() } label: { Text("分析今天") }
                        .dtPrimaryButton()

                    if let analysis {
                        AnalysisSummaryCard(analysis: analysis)
                    }

                    ForEach(enabledSlots) { slot in
                        slotCard(slot)
                    }

                    if !orphanMeals.isEmpty {
                        orphanCard
                    }

                    exerciseCard
                    waterCard
                }
                .dtScreenPadding()
                .padding(.vertical, Tokens.Space.md)
            }
            .dtScreenBackground()
            .navigationTitle(DayIdentifier.displayText(dayID))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        inputSlotID = nil
                        showingMealInput = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .tint(Tokens.Palette.accent)
                }
            }
            .sheet(isPresented: $showingMealInput) {
                MealInputSheet(slots: enabledSlots.isEmpty ? Array(slots) : enabledSlots,
                               dayIdentifier: dayID,
                               initialSlotID: inputSlotID) { runAnalysis() }
            }
            .sheet(isPresented: $showingExerciseInput) {
                ExerciseInputSheet(dayIdentifier: dayID,
                                   weightKg: profile.effectiveWeightKg) { runAnalysis() }
            }
            .onAppear(perform: runAnalysis)
        }
    }

    // MARK: 时段卡片

    private func slotCard(_ slot: MealSlot) -> some View {
        let entries = todayMeals.filter { $0.slotID == slot.slotID }
        return VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            DTSectionHeader(title: slot.name,
                            subtitle: nil,
                            trailing: "\(AnalysisFormat.kcal(entries.reduce(0) { $0 + $1.totalKcal })) kcal")

            if entries.isEmpty {
                Text("还没有记录")
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textTertiary)
            } else {
                ForEach(entries) { entry in
                    mealRow(entry)
                    if entry.id != entries.last?.id { DTDivider() }
                }
            }

            Button {
                inputSlotID = slot.slotID
                showingMealInput = true
            } label: {
                Text("记一笔")
            }
            .dtSecondaryButton()
        }
        .dtCard()
    }

    private func mealRow(_ entry: MealEntry) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                Text(entry.summaryText)
                    .font(Tokens.Typography.subhead)
                    .foregroundStyle(Tokens.Palette.textPrimary)
                Spacer(minLength: Tokens.Space.xxs)
                Text("\(AnalysisFormat.kcal(entry.totalKcal)) kcal")
                    .dtNumber(Tokens.Typography.Number.small)
            }
            Text(entry.rawText)
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
            if entry.needsReview {
                Text("估算把握不高，可长按删除后重新记录")
                    .font(Tokens.Typography.overline)
                    .foregroundStyle(Tokens.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                delete(entry)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var orphanCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            DTSectionHeader(title: "随手记", subtitle: "未归到具体时段", trailing: "\(orphanMeals.count) 条")
            ForEach(orphanMeals) { entry in
                mealRow(entry)
            }
        }
        .dtCard()
    }

    // MARK: 运动卡片

    private var exerciseCard: some View {
        let minutes = DayAggregator.exerciseMinutes(dayIdentifier: dayID, from: exercises)
        return VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            DTSectionHeader(title: "今日运动",
                            subtitle: "只记刻意锻炼，日常走动已算在活动系数里",
                            trailing: "\(AnalysisFormat.kcal(todayBurn)) kcal · \(Int(minutes.rounded())) 分钟")

            if todayExercises.isEmpty {
                Text("今天还没有运动记录")
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Palette.textTertiary)
            } else {
                ForEach(todayExercises) { entry in
                    exerciseRow(entry)
                }
            }

            Button { showingExerciseInput = true } label: { Text("记一笔运动") }
                .dtSecondaryButton()
        }
        .dtCard()
    }

    private func exerciseRow(_ entry: ExerciseEntry) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                Text(entry.summaryText)
                    .font(Tokens.Typography.subhead)
                    .foregroundStyle(Tokens.Palette.textPrimary)
                Spacer(minLength: Tokens.Space.xxs)
                Text("\(AnalysisFormat.kcal(entry.totalKcal)) kcal")
                    .dtNumber(Tokens.Typography.Number.small)
            }
            ForEach(entry.items) { item in
                HStack(spacing: Tokens.Space.xs) {
                    Text("\(item.name) · \(item.minutesText) · \(item.intensity.shortName)")
                        .font(Tokens.Typography.caption)
                        .foregroundStyle(Tokens.Palette.textSecondary)
                    Spacer(minLength: Tokens.Space.xxs)
                    Text("MET \(String(format: "%.1f", item.metValue))")
                        .font(Tokens.Typography.overline)
                        .monospacedDigit()
                        .foregroundStyle(Tokens.Palette.textTertiary)
                }
            }
            if entry.needsReview {
                Text("有条目没匹配到具体运动，按中等强度一般运动估算")
                    .font(Tokens.Typography.overline)
                    .foregroundStyle(Tokens.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                delete(entry)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: 饮水卡片

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            DTSectionHeader(title: "今日饮水", subtitle: nil, trailing: "\(AnalysisFormat.kcal(waterTotalML)) ml")
            HStack(spacing: Tokens.Space.xs) {
                ForEach([200, 300, 500], id: \.self) { amount in
                    Button { addWater(Double(amount)) } label: { Text("+\(amount)") }
                        .dtSecondaryButton()
                }
            }
        }
        .dtCard()
    }

    // MARK: 动作

    private func runAnalysis() {
        let windowDays = max(profile.thresholds.trendWindowDays, 1)
        let days = DayIdentifier.recentIdentifiers(count: windowDays)
        let history = DayAggregator.summaries(days: days, meals: meals, exercises: exercises)

        let context = AnalysisContext(dayIdentifier: dayID,
                                      intake: todayIntake.nutrition,
                                      burnKcal: todayBurn,
                                      profile: profile.snapshot,
                                      thresholds: profile.thresholds,
                                      history: history)
        analysis = services.analysis.analyze(context)
    }

    private func addWater(_ amountML: Double) {
        let entry = WaterEntry(dayIdentifier: dayID, amountML: amountML)
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func delete(_ entry: MealEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        runAnalysis()
    }

    private func delete(_ entry: ExerciseEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        runAnalysis()
    }
}

#Preview("今日页") {
    TodayViewPreviewHost()
        .dtTheme(.default)
}

@MainActor
private struct TodayViewPreviewHost: View {
    private let context = try! SeedData.makePreviewContext()

    var body: some View {
        TodayView()
            .modelContext(context)
    }
}
