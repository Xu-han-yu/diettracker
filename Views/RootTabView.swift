//
//  RootTabView.swift
//  DietTracker
//
//  四个 Tab 的根容器，也是首次启动播种默认数据的地方。
//

import SwiftUI
import SwiftData

struct RootTabView: View {

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今日", systemImage: "square.and.pencil") }
            HistoryView()
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
            TrendView()
                .tabItem { Label("趋势", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(Tokens.Palette.accent)
        .task { await seedIfNeeded() }
    }

    /// 幂等播种：默认 7 个进食时段 + 一份默认档案。
    @MainActor
    private func seedIfNeeded() {
        SeedData.bootstrapIfNeeded(in: modelContext)
    }
}
