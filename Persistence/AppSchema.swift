//
//  AppSchema.swift
//  DietTracker
//
//  SwiftData Schema 的唯一装配处。
//
//  ⚠️ 硬约束（未签名 IPA）：
//    - `cloudKitDatabase: .none` —— 未签名产物没有 entitlements，启用 CloudKit 会崩。
//    - 不引入 App Groups / Keychain Sharing / HealthKit，同理。
//    - 不要添加任何 .entitlements 文件。
//
//  ⚠️ 新增模型时必须加进 `models` 数组，否则运行时会报
//     "Failed to find any currently loaded container for ..."。
//

import Foundation
import SwiftData

enum AppSchema {

    /// 全量模型清单。**加模型就加这里。**
    static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            MealSlot.self,
            MealEntry.self,
            FoodItem.self,
            ExerciseEntry.self,
            ExerciseItem.self,
            WaterEntry.self,
            SupplementEntry.self,
            BodyMetricEntry.self
        ]
    }

    static var schema: Schema { Schema(models) }

    /// 正式容器。
    static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: ModelConfiguration.CloudKitDatabase.none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// 预览 / 单测用内存容器，不落磁盘。
    static func makePreviewContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: ModelConfiguration.CloudKitDatabase.none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
