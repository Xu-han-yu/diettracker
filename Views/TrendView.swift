//
//  TrendView.swift
//  DietTracker
//
//  趋势页：摄入 / 消耗 / 净摄入三条细线 + 多日均值对比 + 运动频率。
//
//  图表全部按主题规范：线宽 2pt、无渐变、网格 0.5pt、低饱和色。
//  x 轴用 dayIdentifier 字符串（分类轴），顺序由数据数组保证升序。
//

import SwiftUI
import SwiftData
import Charts

struct TrendView: View {

    @Environment(\.dtTheme) private var theme

    @Query(sort: \MealEntry.timestamp) private var meals: [MealEntry]
    @Query(sort: \ExerciseEntry.timestamp) private var exercises: [ExerciseEntry]
    @Query private var profiles: [UserProfile]

    @State private var windowDays: Int = 7

    private var profile: UserProfile { profiles.first ?? UserProfile() }
    private var rdi: NutritionProfile { profile.rdi }
    private var thresholds: AnalysisThresholds { profile.thresholds }

    private var days: [String] { DayIdentifier.recentIdentifiers(count: windowDays) }

    private var summaries: [DailySummary] {
        DayAggregator.summaries(days: days, meals: meals, exercises: exercises)
    }

    private var points: [EnergyPoint] {
        summaries.map {
            EnergyPoint(dayIdentifier: $0.dayIdentifier,
                        date: DayIdentifier.date(from: $0.dayIdentifier) ?? Date(),
                        intake: $0.intake.kcal,
                        burn: $0.burnKcal,
                        net: $0.netKcal)
        }
    }

    /// x 轴刻度间隔：窗口大就稀疏一点，否则 30 天的日期会糊成一片。
    private var xAxisStride: Int {
        windowDays > 14 ? 7 : 1
    }

    private var trend: TrendSnapshot { summaries.trendSnapshot(windowDays: windowDays) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.cardSpacing) {
                    windowPicker
                    energyChartCard
                    averagesCard
                    exerciseCard
                    DTDisclaimer()
                }
                .dtScreenPadding()
                .padding(.vertical, Tokens.Space.md)
            }
            .dtScreenBackground()
            .navigationTitle("趋势")
        }
    }

    // MARK: 子视图

    private var windowPicker: some View {
        Picker("窗口", selection: $windowDays) {
            Text("近 7 天").tag(7)
            Text("近 30 天").tag(30)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var energyChartCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            DTSectionHeader(title: "能量趋势",
                            subtitle: "摄入 / 消耗 / 净摄入",
                            trailing: "推荐 \(AnalysisFormat.kcal(rdi.kcal)) kcal")

            Chart {
                ForEach(points) { p in
                    LineMark(x: .value("日期", p.date),
                             y: .value("能量", p.intake),
                             series: .value("系列", "摄入"))
                        .lineStyle(StrokeStyle(lineWidth: Tokens.ChartStyle.lineWidth))
                        .symbolSize(Tokens.ChartStyle.symbolSize)
                    LineMark(x: .value("日期", p.date),
                             y: .value("能量", p.burn),
                             series: .value("系列", "消耗"))
                        .lineStyle(StrokeStyle(lineWidth: Tokens.ChartStyle.lineWidth))
                        .symbolSize(Tokens.ChartStyle.symbolSize)
                    LineMark(x: .value("日期", p.date),
                             y: .value("能量", p.net),
                             series: .value("系列", "净摄入"))
                        .lineStyle(StrokeStyle(lineWidth: Tokens.ChartStyle.lineWidth))
                        .symbolSize(Tokens.ChartStyle.symbolSize)
                }
            }
            .chartForegroundStyleScale([
                "摄入": Tokens.Palette.Chart.intake,
                "消耗": Tokens.Palette.Chart.burn,
                "净摄入": Tokens.Palette.Chart.net
            ])
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: Tokens.ChartStyle.gridLineWidth))
                        .foregroundStyle(Tokens.Palette.Chart.grid)
                    AxisValueLabel()
                        .foregroundStyle(Tokens.Palette.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                    AxisValueLabel()
                        .foregroundStyle(Tokens.Palette.textTertiary)
                }
            }
            .frame(height: Tokens.ChartStyle.defaultHeight)

            HStack(spacing: Tokens.Space.sm) {
                legendDot(color: Tokens.Palette.Chart.intake, text: "摄入")
                legendDot(color: Tokens.Palette.Chart.burn, text: "消耗")
                legendDot(color: Tokens.Palette.Chart.net, text: "净摄入")
                Spacer(minLength: 0)
            }
        }
        .dtCard()
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: Tokens.Space.xxs) {
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .fill(color)
                .frame(width: Tokens.Space.sm, height: Tokens.ChartStyle.lineWidth)
            Text(text)
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textSecondary)
        }
    }

    /// 多日均值 vs RDI。判定口径与今日页一致：数据够就按均值判。
    private var averagesCard: some View {
        let recorded = trend.recordedDays
        let hasEnough = recorded >= thresholds.minimumDaysForConclusion
        let rows = Nutrient.displayOrder.map { nutrient -> NutrientEvaluation in
            let average = trend.average(of: nutrient)
            let target = rdi.value(for: nutrient)
            return NutrientEvaluation(nutrient: nutrient,
                                      actual: average,
                                      assessedValue: average,
                                      basis: hasEnough ? .multiDay(windowDays) : .singleDay,
                                      target: target,
                                      status: thresholds.status(actual: average, target: target))
        }

        return VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            DTSectionHeader(title: "多日均值对比",
                            subtitle: hasEnough
                                ? "按近 \(windowDays) 天共 \(recorded) 天有记录的数据计算"
                                : "只有 \(recorded) 天记录，仅供参考",
                            trailing: nil)
            VStack(spacing: Tokens.Space.sm) {
                ForEach(rows) { NutrientRow(evaluation: $0) }
            }
            Text("均值的分母是「有记录的天数」，没记录的天不会把均值拉低。")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
        .dtCard()
    }

    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            DTSectionHeader(title: "运动情况",
                            subtitle: "近 \(windowDays) 天",
                            trailing: "\(trend.daysWithExercise) / \(trend.recordedDays) 天")

            HStack(spacing: Tokens.Space.xs) {
                DTMetric(label: "日均消耗", value: trend.averageBurnKcal, unit: "kcal")
                DTMetric(label: "日均摄入", value: trend.averageIntakeKcal, unit: "kcal")
                DTMetric(label: "日均净摄入", value: trend.averageNetKcal, unit: "kcal", emphasized: true)
            }

            Text("运动消耗只体现在「净摄入」这一列，不影响上面任何营养素是否达标的判定。")
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Palette.textTertiary)
        }
        .dtCard()
    }
}

// MARK: - 图表数据点

private struct EnergyPoint: Identifiable {
    var id: String { dayIdentifier }
    var dayIdentifier: String
    /// x 轴用 Date（等距时间轴），字符串只当 id 与排序依据。
    var date: Date
    var intake: Double
    var burn: Double
    var net: Double
}

#Preview("趋势页") {
    TrendViewPreviewHost()
        .dtTheme(.default)
}

@MainActor
private struct TrendViewPreviewHost: View {
    private let context = try! SeedData.makePreviewContext()

    var body: some View {
        TrendView()
            .modelContext(context)
    }
}
