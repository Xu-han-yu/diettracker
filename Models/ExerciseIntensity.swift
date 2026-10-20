//
//  ExerciseIntensity.swift
//  DietTracker
//
//  运动强度三档：低 / 中 / 高。解析不出强度时默认中等，用户可手动改。
//

import Foundation

enum ExerciseIntensity: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case moderate
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low:      return "低强度"
        case .moderate: return "中等强度"
        case .high:     return "高强度"
        }
    }

    /// 短标签，用于分段控件
    var shortName: String {
        switch self {
        case .low:      return "低"
        case .moderate: return "中"
        case .high:     return "高"
        }
    }

    /// 在 MET 表中的档位下标（与 ExerciseDatabase 的 metLow/metModerate/metHigh 对应）。
    var metIndex: Int {
        switch self {
        case .low:      return 0
        case .moderate: return 1
        case .high:     return 2
        }
    }

    /// 用户能看懂的强度说明，用于设置页 / 输入卡片的辅助文案。
    var guidance: String {
        switch self {
        case .low:      return "能正常说话、几乎不出汗，比如慢走、拉伸"
        case .moderate: return "微微喘但还能说短句，比如快走、慢跑、骑车通勤"
        case .high:     return "说话困难、大量出汗，比如跑步冲刺、HIIT、对抗性运动"
        }
    }
}
