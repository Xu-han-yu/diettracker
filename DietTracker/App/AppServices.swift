//
//  AppServices.swift
//  DietTracker
//
//  服务容器 + Environment 注入。
//
//  MVP 全部使用本地实现：解析、营养查询、MET 估算、分析都在 App 内完成，
//  不联网、不依赖大模型。将来要接外部 API 只需替换 `live` 里的某一项。
//

import SwiftUI

struct AppServices {

    var foodParser: FoodParsingService
    var nutrition: NutritionLookupService
    var exerciseParser: ExerciseParsingService
    var exerciseCalorie: ExerciseCalorieService
    var analysis: AnalysisEngine
}

extension AppServices {

    /// 正式环境装配。全部是本地实现，离线可用。
    static let live = AppServices(
        foodParser: LocalFoodParsingService(),
        nutrition: LocalNutritionLookupService(),
        exerciseParser: LocalExerciseParsingService(),
        exerciseCalorie: METExerciseCalorieService(),
        analysis: DefaultAnalysisEngine()
    )
}

// MARK: - Environment

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue: AppServices = .live
}

extension EnvironmentValues {
    var appServices: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}

extension View {
    func appServices(_ services: AppServices) -> some View {
        environment(\.appServices, services)
    }
}
