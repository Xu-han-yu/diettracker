//
//  FoodDatabase.swift
//  DietTracker
//
//  本地中式食物营养表。**离线可用，是营养数据的主路径。**
//
//  数据说明：
//   - 数值为每 100g 可食部，参考中国食物成分表与常见烹调后的经验值，属**估算**。
//   - 熟重与生重差异很大（如米饭 116 vs 生米 346），本表一律用**入口状态**的数值。
//   - 所有数字都会经 `Nutrition.scaled(by:)` 按克数缩放后使用。
//
//  扩展方式：往 `all` 数组里加一条即可，别名越多命中率越高。
//

import Foundation

// MARK: - 份量单位

enum PortionUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case bowl    = "碗"
    case piece   = "个"
    case serving = "份"
    case cup     = "杯"
    case slice   = "片"
    case root    = "根"
    case block   = "块"
    case plate   = "盘"
    case spoon   = "勺"
    case item    = "只"
    case bottle  = "瓶"
    case bag     = "袋"
    case handful = "把"
    case gram    = "克"
    case ml      = "毫升"
    case liang   = "两"
    case jin     = "斤"

    var displayName: String { rawValue }

    /// 文本别名 → 单位。解析器用它把「一碗」「两个」转成 PortionUnit。
    var textAliases: [String] {
        switch self {
        case .bowl:    return ["碗"]
        case .piece:   return ["个", "颗", "枚"]
        case .serving: return ["份"]
        case .cup:     return ["杯"]
        case .slice:   return ["片"]
        case .root:    return ["根", "条"]
        case .block:   return ["块"]
        case .plate:   return ["盘", "碟"]
        case .spoon:   return ["勺", "匙"]
        case .item:    return ["只"]
        case .bottle:  return ["瓶"]
        case .bag:     return ["袋", "包"]
        case .handful: return ["把"]
        case .gram:    return ["克", "g"]
        case .ml:      return ["毫升", "ml"]
        case .liang:   return ["两"]
        case .jin:     return ["斤"]
        }
    }

    /// 是否是「绝对重量 / 体积」单位（与食物种类无关，1 两恒为 50g）。
    var isAbsoluteUnit: Bool {
        switch self {
        case .gram, .ml, .liang, .jin: return true
        default: return false
        }
    }

    /// 绝对单位对应的克数。非绝对单位返回 nil（需查食物自身的份量表）。
    var absoluteGrams: Double? {
        switch self {
        case .gram:  return 1
        case .ml:    return 1
        case .liang: return 50
        case .jin:   return 500
        default:     return nil
        }
    }

    static func from(text: String) -> PortionUnit? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        for unit in PortionUnit.allCases {
            if unit.textAliases.contains(where: { $0.lowercased() == t }) { return unit }
        }
        return nil
    }
}

// MARK: - 分类

enum FoodCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case staple
    case protein
    case vegetable
    case fruit
    case dairy
    case drink
    case snack
    case fat
    case dish
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .staple:    return "主食"
        case .protein:   return "肉蛋豆"
        case .vegetable: return "蔬菜"
        case .fruit:     return "水果"
        case .dairy:     return "奶制品"
        case .drink:     return "饮品"
        case .snack:     return "零食"
        case .fat:       return "油脂坚果"
        case .dish:      return "菜肴"
        case .other:     return "其他"
        }
    }
}

// MARK: - 条目

struct FoodEntry: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// 别名。越多越容易命中；建议同时收录全称、简称、口语说法。
    let aliases: [String]
    let category: FoodCategory
    /// 每 100g 可食部营养
    let per100g: Nutrition
    /// 常见份量单位 → 克数
    let portions: [PortionUnit: Double]
    /// 用户没说份量时的默认克数
    let defaultGrams: Double

    func grams(for unit: PortionUnit) -> Double? { portions[unit] }

    /// 取份量：优先查份量表，查不到就退回默认克数。
    func grams(unit: PortionUnit?) -> Double {
        guard let unit else { return defaultGrams }
        if let absolute = unit.absoluteGrams { return absolute }
        return portions[unit] ?? defaultGrams
    }
}

// MARK: - 便捷构造

extension Nutrition {
    /// 紧凑写法：`.per100g(116, 2.6, 0.3, 25.9, ca: 7, fe: 0.3)`
    static func per100g(_ kcal: Double,
                       _ proteinG: Double,
                       _ fatG: Double,
                       _ carbsG: Double,
                       ca calciumMG: Double = 0,
                       fe ironMG: Double = 0,
                       vc vitaminCMG: Double = 0,
                       fb fiberG: Double = 0) -> Nutrition {
        Nutrition(kcal: kcal,
                  proteinG: proteinG,
                  fatG: fatG,
                  carbsG: carbsG,
                  calciumMG: calciumMG,
                  ironMG: ironMG,
                  vitaminCMG: vitaminCMG,
                  fiberG: fiberG)
    }
}

// MARK: - 数据库本体

enum FoodDatabase {

    // 按分类拆成多个子数组：单个超大数组字面量会显著拖慢 Swift 类型检查器。
    static let staples: [FoodEntry] = [

        FoodEntry(id: "rice", name: "米饭", aliases: ["米饭", "白米饭", "大米饭", "蒸米饭", "饭"],
                  category: .staple,
                  per100g: .per100g(116, 2.6, 0.3, 25.9, ca: 7, fe: 0.3, fb: 0.3),
                  portions: [.bowl: 150, .serving: 150], defaultGrams: 150),

        FoodEntry(id: "congee", name: "白粥", aliases: ["白粥", "大米粥", "稀饭", "粥", "米粥"],
                  category: .staple,
                  per100g: .per100g(46, 1.1, 0.3, 9.9, ca: 2, fe: 0.1),
                  portions: [.bowl: 250, .serving: 250], defaultGrams: 250),

        FoodEntry(id: "millet_congee", name: "小米粥", aliases: ["小米粥", "小米"],
                  category: .staple,
                  per100g: .per100g(46, 1.4, 0.4, 8.4, ca: 10, fe: 0.4, fb: 0.2),
                  portions: [.bowl: 250], defaultGrams: 250),

        FoodEntry(id: "mantou", name: "馒头", aliases: ["馒头", "白馒头"],
                  category: .staple,
                  per100g: .per100g(223, 7.0, 1.1, 47.0, ca: 38, fe: 1.8, fb: 1.3),
                  portions: [.piece: 100], defaultGrams: 100),

        FoodEntry(id: "huajuan", name: "花卷", aliases: ["花卷"],
                  category: .staple,
                  per100g: .per100g(214, 6.4, 1.0, 45.0, ca: 30, fe: 1.5, fb: 1.0),
                  portions: [.piece: 80], defaultGrams: 80),

        FoodEntry(id: "noodles", name: "面条", aliases: ["面条", "挂面", "汤面", "清汤面", "阳春面"],
                  category: .staple,
                  per100g: .per100g(110, 2.7, 0.2, 24.3, ca: 8, fe: 0.5, fb: 0.4),
                  portions: [.bowl: 200, .serving: 200], defaultGrams: 200),

        FoodEntry(id: "fried_rice", name: "炒饭", aliases: ["炒饭", "蛋炒饭", "扬州炒饭"],
                  category: .staple,
                  per100g: .per100g(188, 4.5, 6.0, 28.0, ca: 14, fe: 0.8, fb: 0.6),
                  portions: [.bowl: 200, .plate: 250], defaultGrams: 200),

        FoodEntry(id: "baozi_meat", name: "肉包", aliases: ["肉包", "肉包子", "包子", "猪肉包"],
                  category: .staple,
                  per100g: .per100g(227, 7.0, 5.0, 37.0, ca: 20, fe: 1.2, fb: 1.0),
                  portions: [.piece: 80], defaultGrams: 80),

        FoodEntry(id: "jiaozi", name: "饺子", aliases: ["饺子", "水饺", "猪肉白菜饺子", "猪肉白菜饺"],
                  category: .staple,
                  per100g: .per100g(240, 9.0, 8.0, 30.0, ca: 18, fe: 1.4, fb: 1.2),
                  portions: [.piece: 20, .serving: 200, .plate: 250], defaultGrams: 200),

        FoodEntry(id: "wonton", name: "馄饨", aliases: ["馄饨", "云吞", "抄手"],
                  category: .staple,
                  per100g: .per100g(145, 7.5, 4.5, 19.0, ca: 16, fe: 1.0, fb: 0.8),
                  portions: [.piece: 15, .bowl: 200], defaultGrams: 200),

        FoodEntry(id: "youtiao", name: "油条", aliases: ["油条", "油炸鬼"],
                  category: .staple,
                  per100g: .per100g(388, 6.9, 17.6, 51.0, ca: 14, fe: 1.0, fb: 0.9),
                  portions: [.root: 60, .piece: 60], defaultGrams: 60),

        FoodEntry(id: "whole_wheat_bread", name: "全麦面包", aliases: ["全麦面包", "全麦吐司", "吐司", "面包片"],
                  category: .staple,
                  per100g: .per100g(246, 8.8, 3.5, 45.0, ca: 107, fe: 2.0, fb: 6.0),
                  portions: [.slice: 35, .piece: 35], defaultGrams: 70),

        FoodEntry(id: "oatmeal", name: "燕麦粥", aliases: ["燕麦", "燕麦片", "燕麦粥", "麦片", "牛奶燕麦"],
                  category: .staple,
                  per100g: .per100g(68, 2.4, 1.4, 12.0, ca: 30, fe: 0.8, fb: 1.7),
                  portions: [.bowl: 250, .serving: 250], defaultGrams: 250),

        FoodEntry(id: "sweet_potato", name: "红薯", aliases: ["红薯", "地瓜", "烤红薯", "蒸红薯", "番薯"],
                  category: .staple,
                  per100g: .per100g(86, 1.6, 0.2, 20.1, ca: 30, fe: 0.6, vc: 2.4, fb: 3.0),
                  portions: [.piece: 150, .root: 150], defaultGrams: 150),

        FoodEntry(id: "corn", name: "玉米", aliases: ["玉米", "煮玉米", "甜玉米", "玉米棒"],
                  category: .staple,
                  per100g: .per100g(112, 4.0, 1.2, 22.8, ca: 3, fe: 0.5, vc: 6.8, fb: 2.9),
                  portions: [.root: 200, .piece: 200], defaultGrams: 200),

        FoodEntry(id: "potato_steamed", name: "土豆", aliases: ["土豆", "马铃薯", "蒸土豆", "煮土豆"],
                  category: .staple,
                  per100g: .per100g(77, 2.0, 0.1, 17.2, ca: 8, fe: 0.8, vc: 13, fb: 1.8),
                  portions: [.piece: 150], defaultGrams: 150),

        FoodEntry(id: "yam", name: "山药", aliases: ["山药", "蒸山药", "淮山"],
                  category: .staple,
                  per100g: .per100g(57, 1.9, 0.2, 12.4, ca: 16, fe: 0.3, vc: 5, fb: 0.8),
                  portions: [.serving: 150, .root: 200], defaultGrams: 150),

        FoodEntry(id: "buckwheat_noodles", name: "荞麦面", aliases: ["荞麦面", "杂粮面"],
                  category: .staple,
                  per100g: .per100g(115, 4.1, 0.4, 23.0, ca: 13, fe: 0.9, fb: 1.5),
                  portions: [.bowl: 200], defaultGrams: 200),

        FoodEntry(id: "instant_noodles", name: "方便面", aliases: ["方便面", "泡面", "速食面", "桶面"],
                  category: .staple,
                  per100g: .per100g(470, 9.5, 21.1, 60.9, ca: 25, fe: 1.6, fb: 2.0),
                  portions: [.bag: 100, .bowl: 110, .piece: 100], defaultGrams: 100),

    ]

    static let proteins: [FoodEntry] = [
        FoodEntry(id: "egg_boiled", name: "鸡蛋", aliases: ["鸡蛋", "煮鸡蛋", "水煮蛋", "白煮蛋", "蛋"],
                  category: .protein,
                  per100g: .per100g(144, 13.3, 8.8, 2.8, ca: 56, fe: 2.0, fb: 0),
                  portions: [.piece: 50, .item: 50], defaultGrams: 50),

        FoodEntry(id: "egg_fried", name: "煎蛋", aliases: ["煎蛋", "煎鸡蛋", "荷包蛋"],
                  category: .protein,
                  per100g: .per100g(200, 14.0, 15.0, 1.0, ca: 62, fe: 2.2),
                  portions: [.piece: 55], defaultGrams: 55),

        FoodEntry(id: "chicken_breast", name: "鸡胸肉", aliases: ["鸡胸肉", "鸡胸", "鸡脯肉", "鸡柳"],
                  category: .protein,
                  per100g: .per100g(165, 31.0, 3.6, 0, ca: 15, fe: 1.0, fb: 0),
                  portions: [.serving: 100, .block: 100], defaultGrams: 100),

        FoodEntry(id: "chicken_thigh", name: "鸡腿", aliases: ["鸡腿", "鸡腿肉", "琵琶腿"],
                  category: .protein,
                  per100g: .per100g(181, 24.0, 9.0, 0, ca: 12, fe: 1.2),
                  portions: [.piece: 100, .item: 100], defaultGrams: 100),

        FoodEntry(id: "chicken_wing", name: "鸡翅", aliases: ["鸡翅", "烤鸡翅", "鸡中翅"],
                  category: .protein,
                  per100g: .per100g(194, 24.0, 10.0, 0.5, ca: 14, fe: 1.0),
                  portions: [.piece: 40, .item: 40], defaultGrams: 80),

        FoodEntry(id: "pork_loin", name: "猪里脊", aliases: ["猪里脊", "里脊肉", "瘦肉", "猪瘦肉"],
                  category: .protein,
                  per100g: .per100g(155, 26.0, 5.0, 0, ca: 6, fe: 1.5),
                  portions: [.serving: 100], defaultGrams: 100),

        FoodEntry(id: "pork_belly", name: "五花肉", aliases: ["五花肉", "肥肉", "红烧肉"],
                  category: .protein,
                  per100g: .per100g(395, 13.0, 37.0, 0, ca: 8, fe: 0.9),
                  portions: [.serving: 100, .slice: 25], defaultGrams: 100),

        FoodEntry(id: "beef", name: "牛肉", aliases: ["牛肉", "牛腱", "卤牛肉", "炖牛肉", "牛排"],
                  category: .protein,
                  per100g: .per100g(217, 30.0, 10.0, 0, ca: 10, fe: 2.8),
                  portions: [.serving: 100, .block: 100], defaultGrams: 100),

        FoodEntry(id: "lamb", name: "羊肉", aliases: ["羊肉", "羊排", "涮羊肉", "烤羊肉"],
                  category: .protein,
                  per100g: .per100g(203, 25.0, 11.0, 0, ca: 9, fe: 2.3),
                  portions: [.serving: 100], defaultGrams: 100),

        FoodEntry(id: "duck", name: "鸭肉", aliases: ["鸭肉", "烤鸭", "鸭腿"],
                  category: .protein,
                  per100g: .per100g(240, 19.0, 17.0, 0.5, ca: 12, fe: 2.5),
                  portions: [.serving: 100], defaultGrams: 100),

        FoodEntry(id: "salmon", name: "三文鱼", aliases: ["三文鱼", "鲑鱼", "刺身三文鱼"],
                  category: .protein,
                  per100g: .per100g(208, 20.0, 13.0, 0, ca: 12, fe: 0.8),
                  portions: [.serving: 120, .block: 120], defaultGrams: 120),

        FoodEntry(id: "sea_bass", name: "鲈鱼", aliases: ["鲈鱼", "清蒸鲈鱼", "蒸鱼", "鱼肉", "鱼"],
                  category: .protein,
                  per100g: .per100g(105, 18.6, 3.4, 0, ca: 138, fe: 2.0),
                  portions: [.serving: 150, .root: 300], defaultGrams: 150),

        FoodEntry(id: "shrimp", name: "虾", aliases: ["虾", "基围虾", "虾仁", "煮虾", "白灼虾"],
                  category: .protein,
                  per100g: .per100g(99, 24.0, 0.3, 0.2, ca: 60, fe: 1.5),
                  portions: [.item: 10, .serving: 100], defaultGrams: 100),

        FoodEntry(id: "tofu_firm", name: "北豆腐", aliases: ["北豆腐", "豆腐", "老豆腐", "煎豆腐"],
                  category: .protein,
                  per100g: .per100g(116, 12.2, 4.8, 1.5, ca: 138, fe: 2.5, fb: 0.5),
                  portions: [.block: 150, .serving: 150], defaultGrams: 150),

        FoodEntry(id: "tofu_soft", name: "嫩豆腐", aliases: ["嫩豆腐", "南豆腐", "内酯豆腐"],
                  category: .protein,
                  per100g: .per100g(57, 6.2, 2.5, 2.4, ca: 116, fe: 1.5, fb: 0.4),
                  portions: [.block: 200], defaultGrams: 200),

        FoodEntry(id: "soy_milk", name: "豆浆", aliases: ["豆浆", "现磨豆浆", "无糖豆浆"],
                  category: .protein,
                  per100g: .per100g(31, 3.0, 1.6, 1.2, ca: 10, fe: 0.5, fb: 0.4),
                  portions: [.cup: 250, .bottle: 300], defaultGrams: 250),

        FoodEntry(id: "chicken_liver", name: "鸡肝", aliases: ["鸡肝", "动物肝脏", "猪肝"],
                  category: .protein,
                  per100g: .per100g(129, 17.0, 5.0, 5.0, ca: 10, fe: 12.0, vc: 18),
                  portions: [.serving: 80], defaultGrams: 80),

        FoodEntry(id: "bacon", name: "培根", aliases: ["培根", "煎培根", "烟肉"],
                  category: .protein,
                  per100g: .per100g(400, 23.0, 34.0, 1.0, ca: 10, fe: 1.2),
                  portions: [.slice: 15], defaultGrams: 30),

    ]

    static let vegetables: [FoodEntry] = [
        FoodEntry(id: "broccoli", name: "西兰花", aliases: ["西兰花", "西蓝花", "青花菜"],
                  category: .vegetable,
                  per100g: .per100g(35, 2.4, 0.4, 7.2, ca: 47, fe: 0.7, vc: 89, fb: 3.3),
                  portions: [.serving: 150, .plate: 200], defaultGrams: 150),

        FoodEntry(id: "spinach", name: "菠菜", aliases: ["菠菜"],
                  category: .vegetable,
                  per100g: .per100g(23, 2.9, 0.4, 3.6, ca: 99, fe: 2.7, vc: 32, fb: 2.2),
                  portions: [.serving: 150, .plate: 200], defaultGrams: 150),

        FoodEntry(id: "lettuce", name: "生菜", aliases: ["生菜", "西生菜", "沙拉菜"],
                  category: .vegetable,
                  per100g: .per100g(15, 1.4, 0.2, 2.9, ca: 36, fe: 0.9, vc: 18, fb: 1.3),
                  portions: [.serving: 100], defaultGrams: 100),

        FoodEntry(id: "cabbage", name: "白菜", aliases: ["白菜", "大白菜", "小白菜", "青菜", "上海青"],
                  category: .vegetable,
                  per100g: .per100g(20, 1.5, 0.2, 3.2, ca: 50, fe: 0.7, vc: 31, fb: 1.0),
                  portions: [.serving: 150, .plate: 200], defaultGrams: 150),

        FoodEntry(id: "tomato", name: "番茄", aliases: ["番茄", "西红柿", "圣女果", "小番茄"],
                  category: .vegetable,
                  per100g: .per100g(20, 0.9, 0.2, 4.0, ca: 10, fe: 0.3, vc: 19, fb: 1.2),
                  portions: [.piece: 150, .item: 20], defaultGrams: 150),

        FoodEntry(id: "cucumber", name: "黄瓜", aliases: ["黄瓜", "青瓜"],
                  category: .vegetable,
                  per100g: .per100g(16, 0.8, 0.2, 2.9, ca: 16, fe: 0.3, vc: 9, fb: 0.5),
                  portions: [.root: 200, .serving: 150], defaultGrams: 150),

        FoodEntry(id: "carrot", name: "胡萝卜", aliases: ["胡萝卜", "红萝卜"],
                  category: .vegetable,
                  per100g: .per100g(41, 0.9, 0.2, 9.6, ca: 33, fe: 0.3, vc: 6, fb: 2.8),
                  portions: [.root: 100, .piece: 100], defaultGrams: 100),

        FoodEntry(id: "eggplant", name: "茄子", aliases: ["茄子", "红烧茄子", "鱼香茄子"],
                  category: .vegetable,
                  per100g: .per100g(85, 1.0, 6.0, 6.5, ca: 12, fe: 0.5, vc: 5, fb: 2.5),
                  portions: [.serving: 150, .plate: 200], defaultGrams: 150),

        FoodEntry(id: "green_pepper", name: "青椒", aliases: ["青椒", "柿子椒", "彩椒", "甜椒"],
                  category: .vegetable,
                  per100g: .per100g(22, 1.4, 0.3, 5.4, ca: 10, fe: 0.5, vc: 80, fb: 1.4),
                  portions: [.piece: 80, .serving: 120], defaultGrams: 100),

        FoodEntry(id: "mushroom", name: "蘑菇", aliases: ["蘑菇", "口蘑", "白蘑菇", "菌菇"],
                  category: .vegetable,
                  per100g: .per100g(22, 3.1, 0.3, 3.3, ca: 2, fe: 1.0, vc: 2, fb: 2.1),
                  portions: [.serving: 100], defaultGrams: 100),

        FoodEntry(id: "shiitake", name: "香菇", aliases: ["香菇", "鲜香菇", "冬菇"],
                  category: .vegetable,
                  per100g: .per100g(26, 2.2, 0.3, 5.2, ca: 3, fe: 0.4, vc: 1, fb: 3.3),
                  portions: [.serving: 100], defaultGrams: 100),

        FoodEntry(id: "green_beans", name: "四季豆", aliases: ["四季豆", "豆角", "扁豆", "青豆角"],
                  category: .vegetable,
                  per100g: .per100g(31, 1.8, 0.2, 5.7, ca: 42, fe: 1.5, vc: 12, fb: 3.2),
                  portions: [.serving: 150], defaultGrams: 150),

        FoodEntry(id: "onion", name: "洋葱", aliases: ["洋葱"],
                  category: .vegetable,
                  per100g: .per100g(40, 1.1, 0.1, 9.3, ca: 24, fe: 0.3, vc: 7, fb: 1.7),
                  portions: [.piece: 100], defaultGrams: 100),

        FoodEntry(id: "pumpkin", name: "南瓜", aliases: ["南瓜", "蒸南瓜"],
                  category: .vegetable,
                  per100g: .per100g(22, 0.7, 0.1, 5.3, ca: 16, fe: 0.4, vc: 9, fb: 0.8),
                  portions: [.serving: 150], defaultGrams: 150),

        FoodEntry(id: "kelp", name: "海带", aliases: ["海带", "海带丝", "凉拌海带"],
                  category: .vegetable,
                  per100g: .per100g(13, 1.2, 0.1, 2.1, ca: 46, fe: 1.0, fb: 0.5),
                  portions: [.serving: 100], defaultGrams: 100),

        FoodEntry(id: "celery", name: "芹菜", aliases: ["芹菜", "西芹"],
                  category: .vegetable,
                  per100g: .per100g(14, 0.7, 0.2, 3.0, ca: 40, fe: 0.6, vc: 8, fb: 1.4),
                  portions: [.serving: 100], defaultGrams: 100),

        FoodEntry(id: "winter_melon", name: "冬瓜", aliases: ["冬瓜", "冬瓜汤"],
                  category: .vegetable,
                  per100g: .per100g(12, 0.4, 0.2, 2.6, ca: 19, fe: 0.2, vc: 18, fb: 0.7),
                  portions: [.serving: 150, .bowl: 250], defaultGrams: 150),

    ]

    static let fruits: [FoodEntry] = [
        FoodEntry(id: "apple", name: "苹果", aliases: ["苹果"],
                  category: .fruit,
                  per100g: .per100g(53, 0.3, 0.2, 13.5, ca: 4, fe: 0.1, vc: 4, fb: 2.4),
                  portions: [.piece: 200], defaultGrams: 200),

        FoodEntry(id: "banana", name: "香蕉", aliases: ["香蕉"],
                  category: .fruit,
                  per100g: .per100g(93, 1.4, 0.2, 22.0, ca: 7, fe: 0.3, vc: 8, fb: 2.6),
                  portions: [.root: 120, .piece: 120], defaultGrams: 120),

        FoodEntry(id: "orange", name: "橙子", aliases: ["橙子", "橘子", "柑橘", "沃柑"],
                  category: .fruit,
                  per100g: .per100g(48, 0.8, 0.1, 11.0, ca: 40, fe: 0.2, vc: 53, fb: 2.4),
                  portions: [.piece: 200], defaultGrams: 200),

        FoodEntry(id: "grape", name: "葡萄", aliases: ["葡萄", "提子"],
                  category: .fruit,
                  per100g: .per100g(45, 0.5, 0.2, 10.3, ca: 10, fe: 0.2, vc: 3, fb: 0.9),
                  portions: [.serving: 150], defaultGrams: 150),

        FoodEntry(id: "watermelon", name: "西瓜", aliases: ["西瓜"],
                  category: .fruit,
                  per100g: .per100g(31, 0.5, 0.1, 7.9, ca: 7, fe: 0.2, vc: 8, fb: 0.4),
                  portions: [.block: 200, .serving: 200], defaultGrams: 200),

        FoodEntry(id: "kiwi", name: "猕猴桃", aliases: ["猕猴桃", "奇异果"],
                  category: .fruit,
                  per100g: .per100g(61, 1.1, 0.5, 14.7, ca: 34, fe: 0.3, vc: 62, fb: 3.0),
                  portions: [.piece: 90], defaultGrams: 90),

        FoodEntry(id: "strawberry", name: "草莓", aliases: ["草莓"],
                  category: .fruit,
                  per100g: .per100g(32, 1.0, 0.2, 7.1, ca: 16, fe: 0.4, vc: 59, fb: 2.0),
                  portions: [.serving: 150], defaultGrams: 150),

        FoodEntry(id: "pear", name: "梨", aliases: ["梨", "雪梨", "鸭梨"],
                  category: .fruit,
                  per100g: .per100g(51, 0.3, 0.1, 13.1, ca: 5, fe: 0.2, vc: 4, fb: 3.1),
                  portions: [.piece: 180], defaultGrams: 180),

        FoodEntry(id: "blueberry", name: "蓝莓", aliases: ["蓝莓"],
                  category: .fruit,
                  per100g: .per100g(57, 0.7, 0.3, 14.5, ca: 6, fe: 0.3, vc: 10, fb: 2.4),
                  portions: [.serving: 100], defaultGrams: 100),

        FoodEntry(id: "peach", name: "桃子", aliases: ["桃子", "水蜜桃", "油桃"],
                  category: .fruit,
                  per100g: .per100g(39, 0.9, 0.3, 9.5, ca: 6, fe: 0.3, vc: 7, fb: 1.5),
                  portions: [.piece: 180], defaultGrams: 180),

    ]

    static let dairy: [FoodEntry] = [
        FoodEntry(id: "milk", name: "牛奶", aliases: ["牛奶", "纯牛奶", "全脂牛奶"],
                  category: .dairy,
                  per100g: .per100g(54, 3.0, 3.2, 3.4, ca: 104, fe: 0.1, vc: 1),
                  portions: [.cup: 250, .bottle: 250, .bag: 200], defaultGrams: 250),

        FoodEntry(id: "yogurt", name: "酸奶", aliases: ["酸奶", "原味酸奶", "希腊酸奶"],
                  category: .dairy,
                  per100g: .per100g(72, 2.5, 2.7, 9.3, ca: 118, fe: 0.1, vc: 1),
                  portions: [.cup: 150, .bottle: 100, .bag: 100], defaultGrams: 150),

        FoodEntry(id: "cheese", name: "奶酪", aliases: ["奶酪", "芝士", "起司", "干酪"],
                  category: .dairy,
                  per100g: .per100g(328, 25.7, 23.5, 3.5, ca: 799, fe: 0.6),
                  portions: [.slice: 20], defaultGrams: 20),

    ]

    static let drinks: [FoodEntry] = [
        FoodEntry(id: "milk_tea", name: "奶茶", aliases: ["奶茶", "珍珠奶茶", "波霸奶茶"],
                  category: .drink,
                  per100g: .per100g(90, 1.0, 3.0, 14.0, ca: 30, fe: 0.1),
                  portions: [.cup: 500, .bottle: 500], defaultGrams: 500),

        FoodEntry(id: "americano", name: "美式咖啡", aliases: ["美式", "美式咖啡", "黑咖啡", "咖啡"],
                  category: .drink,
                  per100g: .per100g(2, 0.1, 0, 0.3, ca: 2),
                  portions: [.cup: 300, .bottle: 300], defaultGrams: 300),

        FoodEntry(id: "latte", name: "拿铁", aliases: ["拿铁", "生椰拿铁", "牛奶咖啡"],
                  category: .drink,
                  per100g: .per100g(47, 2.4, 2.4, 3.9, ca: 90),
                  portions: [.cup: 300], defaultGrams: 300),

        FoodEntry(id: "orange_juice", name: "橙汁", aliases: ["橙汁", "鲜榨橙汁", "果汁"],
                  category: .drink,
                  per100g: .per100g(45, 0.7, 0.2, 10.4, ca: 11, fe: 0.2, vc: 50, fb: 0.2),
                  portions: [.cup: 250, .bottle: 300], defaultGrams: 250),

        FoodEntry(id: "cola", name: "可乐", aliases: ["可乐", "汽水", "碳酸饮料"],
                  category: .drink,
                  per100g: .per100g(43, 0, 0, 10.6, ca: 2),
                  portions: [.bottle: 330, .cup: 330], defaultGrams: 330),

        FoodEntry(id: "beer", name: "啤酒", aliases: ["啤酒"],
                  category: .drink,
                  per100g: .per100g(32, 0.4, 0, 3.1, ca: 4),
                  portions: [.bottle: 500, .cup: 330], defaultGrams: 500),

        FoodEntry(id: "water", name: "水", aliases: ["水", "白开水", "矿泉水"],
                  category: .drink,
                  per100g: .per100g(0, 0, 0, 0),
                  portions: [.cup: 250, .bottle: 500, .ml: 1], defaultGrams: 250),

    ]

    static let fats: [FoodEntry] = [
        FoodEntry(id: "peanut", name: "花生", aliases: ["花生", "炒花生", "花生米"],
                  category: .fat,
                  per100g: .per100g(589, 24.0, 48.0, 21.0, ca: 47, fe: 2.1, fb: 8.5),
                  portions: [.handful: 30, .serving: 30], defaultGrams: 30),

        FoodEntry(id: "walnut", name: "核桃", aliases: ["核桃", "核桃仁"],
                  category: .fat,
                  per100g: .per100g(646, 15.0, 65.0, 13.7, ca: 98, fe: 2.9, fb: 6.7),
                  portions: [.piece: 10, .handful: 25], defaultGrams: 25),

        FoodEntry(id: "almond", name: "杏仁", aliases: ["杏仁", "巴旦木", "扁桃仁"],
                  category: .fat,
                  per100g: .per100g(578, 21.2, 49.9, 21.6, ca: 269, fe: 3.7, fb: 12.5),
                  portions: [.handful: 25], defaultGrams: 25),

        FoodEntry(id: "cooking_oil", name: "食用油", aliases: ["食用油", "油", "植物油", "橄榄油"],
                  category: .fat,
                  per100g: .per100g(899, 0, 99.9, 0),
                  portions: [.spoon: 10], defaultGrams: 10),

        FoodEntry(id: "sesame_paste", name: "芝麻酱", aliases: ["芝麻酱", "麻酱"],
                  category: .fat,
                  per100g: .per100g(630, 20.0, 53.0, 17.0, ca: 1170, fe: 50, fb: 5.9),
                  portions: [.spoon: 15], defaultGrams: 15),

    ]

    static let dishes: [FoodEntry] = [
        FoodEntry(id: "tomato_egg", name: "番茄炒蛋", aliases: ["番茄炒蛋", "西红柿炒鸡蛋", "番茄炒鸡蛋"],
                  category: .dish,
                  per100g: .per100g(105, 6.5, 7.5, 4.5, ca: 30, fe: 1.2, vc: 14, fb: 1.0),
                  portions: [.plate: 250, .serving: 200], defaultGrams: 200),

        FoodEntry(id: "mapo_tofu", name: "麻婆豆腐", aliases: ["麻婆豆腐"],
                  category: .dish,
                  per100g: .per100g(130, 9.0, 9.5, 3.5, ca: 120, fe: 2.2, fb: 1.2),
                  portions: [.plate: 250], defaultGrams: 200),

        FoodEntry(id: "kungpao_chicken", name: "宫保鸡丁", aliases: ["宫保鸡丁"],
                  category: .dish,
                  per100g: .per100g(200, 12.0, 12.0, 8.0, ca: 20, fe: 1.5, fb: 1.0),
                  portions: [.plate: 250], defaultGrams: 200),

        FoodEntry(id: "hotpot", name: "火锅", aliases: ["火锅", "涮锅", "麻辣烫"],
                  category: .dish,
                  per100g: .per100g(180, 10.0, 12.0, 8.0, ca: 30, fe: 1.8, fb: 1.2),
                  portions: [.serving: 400], defaultGrams: 400),

        FoodEntry(id: "salad", name: "蔬菜沙拉", aliases: ["沙拉", "蔬菜沙拉", "轻食沙拉"],
                  category: .dish,
                  per100g: .per100g(35, 1.2, 1.5, 4.5, ca: 30, fe: 0.6, vc: 25, fb: 2.0),
                  portions: [.serving: 150, .plate: 200], defaultGrams: 150),

        FoodEntry(id: "pizza", name: "披萨", aliases: ["披萨", "比萨", "pizza"],
                  category: .dish,
                  per100g: .per100g(266, 11.0, 10.0, 33.0, ca: 130, fe: 1.5, fb: 2.3),
                  portions: [.slice: 100, .block: 100], defaultGrams: 100),

        FoodEntry(id: "burger", name: "汉堡", aliases: ["汉堡", "汉堡包"],
                  category: .dish,
                  per100g: .per100g(250, 12.0, 11.0, 26.0, ca: 90, fe: 1.8, fb: 1.5),
                  portions: [.piece: 150], defaultGrams: 150),

        FoodEntry(id: "french_fries", name: "薯条", aliases: ["薯条", "炸薯条"],
                  category: .dish,
                  per100g: .per100g(312, 3.4, 15.0, 41.0, ca: 12, fe: 0.8, fb: 3.5),
                  portions: [.serving: 100, .bag: 120], defaultGrams: 100),

        FoodEntry(id: "fried_chicken", name: "炸鸡", aliases: ["炸鸡", "炸鸡腿", "炸鸡排", "鸡排"],
                  category: .dish,
                  per100g: .per100g(279, 17.0, 17.0, 14.0, ca: 20, fe: 1.2),
                  portions: [.piece: 120], defaultGrams: 120),

        FoodEntry(id: "sugar", name: "白糖", aliases: ["白糖", "糖", "砂糖"],
                  category: .other,
                  per100g: .per100g(400, 0, 0, 99.9),
                  portions: [.spoon: 8], defaultGrams: 8)
    ]

    /// 全表。往这里加分类即可，索引与搜索会自动覆盖。
    static let all: [FoodEntry] = staples + proteins + vegetables + fruits
                                 + dairy + drinks + fats + dishes

    // MARK: 索引

    /// 别名 → 条目，按别名长度降序，保证「西兰花」优先于「花」这类短别名命中。
    static let aliasIndex: [(alias: String, entry: FoodEntry)] = {
        var pairs: [(String, FoodEntry)] = []
        for entry in all {
            for alias in entry.aliases {
                pairs.append((alias, entry))
            }
        }
        return pairs.sorted { $0.0.count > $1.0.count }
    }()

    static func entry(id: String) -> FoodEntry? {
        all.first { $0.id == id }
    }

    /// 在文本中找最长命中的食物。返回 (条目, 命中的别名)。
    static func match(in text: String) -> (entry: FoodEntry, alias: String)? {
        for (alias, entry) in aliasIndex {
            if text.contains(alias) { return (entry, alias) }
        }
        return nil
    }

    /// 设置页 / 手动添加食物的搜索用。
    static func search(_ keyword: String) -> [FoodEntry] {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return [] }
        return all.filter { entry in
            entry.name.contains(k) || entry.aliases.contains { $0.contains(k) }
        }
    }

    /// 未识别食物时的通用兜底值（每 100g）。
    /// 用「常见混合膳食」的均值，明显标记为估算，UI 必须提示用户修正。
    static let unknownPer100g = Nutrition.per100g(150, 6.0, 5.0, 18.0,
                                                  ca: 30, fe: 1.0, vc: 5, fb: 1.5)

    /// 未识别食物时的默认克数。
    static let unknownDefaultGrams: Double = 150
}
