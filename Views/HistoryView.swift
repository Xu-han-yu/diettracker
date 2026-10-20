//
//  HistoryView.swift
//  DietTracker
//
//  历史页：按日回溯、搜索、删除、补记。
//
//  列表底色统一走 Tokens，用 `.scrollContentBackground(.hidden)` 关掉系统默认分组灰，
//  否则冷灰极简的底色会被 UIKit 的灰盖掉。
//

import SwiftUI
import SwiftData

struct HistoryView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \MealEntry.timestamp) private var meals: [MealEntry]
    @Query(sort: \ExerciseEntry.timestamp) private var exercises: [ExerciseEntry]
    @Query private var profiles: [UserProfile]

    @State private var searchText: String = ""

    /// 最多回溯的天数，避免一次性渲染几百条拖慢列表。
    private static let maxDays = 30

    private var profile: UserProfile { profiles.first ?? UserProfile() }

    private var filteredMeals: [MealEntry] {
        guard !searchText.isEmpty else { return meals }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return meals }
        return meals.filter { entry in
            entry.rawText.localizedCaseInsensitiveContains(q)
                || entry.items.contains { $0.name.localizedCaseInsensitiveContains(q) }
        }
    }

    private var filteredExercises: [ExerciseEntry] {
        guard !searchText.isEmpty else { return exercises }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return exercises }
        return exercises.filter { entry in
            entry.rawText.localizedCaseInsensitiveContains(q)
                || entry.items.contains { $0.name.localizedCaseInsensitiveContains(q) }
        }
    }

    private var days: [String] {
        var set = Set<String>()
        set.formUnion(filteredMeals.map { $0.dayIdentifier })
        set.formUnion(filteredExercises.map { $0.dayIdentifier })
        return set.sorted(by: >).prefix(Self.maxDays).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if days.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(days, id: \.self) { day in
                            Section {
                                ForEach(meals(for: day)) { entry in
                                    mealRow(entry)
                                        .listRowBackground(Tokens.Palette.surface)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) { delete(entry) } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                }
                                ForEach(exercises(for: day)) { entry in
                                    exerciseRow(entry)
                                        .listRowBackground(Tokens.Palette.surface)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) { delete(entry) } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                dayHeader(day)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .dtScreenBackground()
            .navigationTitle("历史")
            .searchable(text: $searchText, prompt: "搜索食物或运动")
        }
    }

    // MARK: 子视图

    private var emptyState: some View {
        VStack(spacing: Tokens.Space.sm) {
            Text(meals.isEmpty && exercises.isEmpty ? "还没有任何记录" : "没有匹配的记录")
                .font(Tokens.Typography.headline)
                .foregroundStyle(Tokens.Palette.textPrimary)
            Text("在「今日」页随手记一笔，这里就会按天列出来。")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textSecondary)
                .multilineTextAlignment(.center)
            DTDisclaimer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Tokens.Space.lg)
    }

    private func dayHeader(_ day: String) -> some View {
        let intake = DayAggregator.intake(dayIdentifier: day, from: meals)
        let burn = DayAggregator.burnKcal(dayIdentifier: day, from: exercises)
        return HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
            Text(DayIdentifier.displayText(day))
                .font(Tokens.Typography.headline)
                .foregroundStyle(Tokens.Palette.textPrimary)
            Spacer(minLength: Tokens.Space.xxs)
            Text("摄入 \(AnalysisFormat.kcal(intake.nutrition.kcal)) / 运动 \(AnalysisFormat.kcal(burn)) / 净 \(AnalysisFormat.kcal(intake.nutrition.kcal - burn))")
                .font(Tokens.Typography.caption)
                .monospacedDigit()
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
        .textCase(nil)
    }

    private func mealRow(_ entry: MealEntry) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                Text(entry.slotName.isEmpty ? "随手记" : entry.slotName)
                    .font(Tokens.Typography.overline)
                    .tracking(Tokens.Typography.overlineTracking)
                    .foregroundStyle(Tokens.Palette.accentText)
                Spacer(minLength: Tokens.Space.xxs)
                Text("\(AnalysisFormat.kcal(entry.totalKcal)) kcal")
                    .dtNumber(Tokens.Typography.Number.small)
            }
            Text(entry.summaryText)
                .font(Tokens.Typography.subhead)
                .foregroundStyle(Tokens.Palette.textPrimary)
            Text(entry.rawText)
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
        .padding(.vertical, Tokens.Space.xxs)
    }

    private func exerciseRow(_ entry: ExerciseEntry) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                Text("运动")
                    .font(Tokens.Typography.overline)
                    .tracking(Tokens.Typography.overlineTracking)
                    .foregroundStyle(Tokens.Palette.textSecondary)
                Spacer(minLength: Tokens.Space.xxs)
                Text("\(AnalysisFormat.kcal(entry.totalKcal)) kcal")
                    .dtNumber(Tokens.Typography.Number.small)
            }
            Text(entry.summaryText)
                .font(Tokens.Typography.subhead)
                .foregroundStyle(Tokens.Palette.textPrimary)
        }
        .padding(.vertical, Tokens.Space.xxs)
    }

    // MARK: 数据

    private func meals(for day: String) -> [MealEntry] {
        filteredMeals.filter { $0.dayIdentifier == day }
    }

    private func exercises(for day: String) -> [ExerciseEntry] {
        filteredExercises.filter { $0.dayIdentifier == day }
    }

    private func delete(_ entry: MealEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    private func delete(_ entry: ExerciseEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }
}

#Preview("历史页") {
    HistoryViewPreviewHost()
        .dtTheme(.default)
}

@MainActor
private struct HistoryViewPreviewHost: View {
    private let context = try! SeedData.makePreviewContext()

    var body: some View {
        HistoryView()
            .modelContext(context)
    }
}
