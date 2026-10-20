//
//  DietTrackerApp.swift
//  DietTracker
//
//  应用入口。
//
//  ⚠️ 硬约束（未签名 IPA）：
//   - 容器用 `cloudKitDatabase: .none`，没有任何 entitlements 可用。
//   - 不在本文件引入 HealthKit / Keychain / App Groups 相关代码。
//

import SwiftUI
import SwiftData

@main
struct DietTrackerApp: App {

    private let container: ModelContainer

    init() {
        do {
            container = try AppSchema.makeContainer()
        } catch {
            // 容器起不来时 App 没有任何可用状态，直接崩比白屏好定位
            fatalError("SwiftData 容器创建失败：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .modelContainer(container)
                .appServices(.live)
                .dtTheme(.default)
        }
    }
}
