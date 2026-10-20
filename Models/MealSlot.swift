//
//  MealSlot.swift
//  DietTracker
//
//  可配置进食时段。默认 7 个：早餐 / 午餐 / 晚餐 / 上午加餐 / 下午加餐 / 夜宵 / 饮品。
//  用户可在设置页增删、改名、调顺序、停用。
//
//  ⚠️ MealEntry 会冗余存 `slotName`（快照），所以时段改名不会篡改历史记录。
//

import Foundation
import SwiftData

/// 默认时段的种子数据（不持久化，仅用于首次启动播种）。
struct MealSlotSeed: Hashable, Sendable {
    let slotID: String
    let name: String
    let hourOfDay: Int

    static let defaults: [MealSlotSeed] = [
        MealSlotSeed(slotID: "breakfast",   name: "早餐",    hourOfDay: 8),
        MealSlotSeed(slotID: "morningSnack", name: "上午加餐", hourOfDay: 10),
        MealSlotSeed(slotID: "lunch",       name: "午餐",    hourOfDay: 12),
        MealSlotSeed(slotID: "afternoonSnack", name: "下午加餐", hourOfDay: 15),
        MealSlotSeed(slotID: "dinner",      name: "晚餐",    hourOfDay: 18),
        MealSlotSeed(slotID: "lateNight",   name: "夜宵",    hourOfDay: 22),
        MealSlotSeed(slotID: "drinks",      name: "饮品",    hourOfDay: 16)
    ]
}

@Model
final class MealSlot {

    var slotID: String = ""
    var name: String = ""
    /// 排序位。数值小的排在前面。
    var sortOrder: Int = 0
    /// 代表小时（0–23）。仅用于排序与「随手记」自动归类，不参与任何营养计算。
    var hourOfDay: Int = 12
    var isEnabled: Bool = true
    /// 用户自建的时段，允许删除；内置时段只允许停用以保留历史可追溯性。
    var isCustom: Bool = false

    /// SwiftData 取回对象时需要无参 init；自定义 init 会让编译器不再合成，必须显式补上。
    init() {}

    init(slotID: String,
         name: String,
         sortOrder: Int,
         hourOfDay: Int,
         isEnabled: Bool = true,
         isCustom: Bool = false) {
        self.slotID = slotID
        self.name = name
        self.sortOrder = sortOrder
        self.hourOfDay = hourOfDay
        self.isEnabled = isEnabled
        self.isCustom = isCustom
    }

    convenience init(seed: MealSlotSeed, sortOrder: Int) {
        self.init(slotID: seed.slotID,
                  name: seed.name,
                  sortOrder: sortOrder,
                  hourOfDay: seed.hourOfDay,
                  isEnabled: true,
                  isCustom: false)
    }
}

// MARK: - 随手记自动归类

extension MealSlot {
    /// 按小时找最近的已启用时段；没有可用时段时返回 nil（调用方回落到「随手记」）。
    static func nearestSlot(to date: Date, from slots: [MealSlot]) -> MealSlot? {
        let hour = Calendar.current.component(.hour, from: date)
        let enabled = slots.filter { $0.isEnabled }
        return enabled.min { a, b in
            abs(a.hourOfDay - hour) < abs(b.hourOfDay - hour)
        }
    }
}
