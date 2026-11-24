import Foundation

enum EnergyShared {
    static let appGroupID = "group.com.april.smallwins"
    static let storageKey = "yuanqi.persisted.data.v1"
    static let seedVersionKey = "yuanqi.seed.version"
    static let widgetSyncPendingKey = "yuanqi.widget.sync.pending"
    private static let snapshotFileName = "yuanqi-energy-data.json"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func readData() -> Data? {
        readWidgetData()
    }

    static func readWidgetData() -> Data? {
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(snapshotFileName),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let data = defaults.data(forKey: storageKey) {
            return data
        }
        return nil
    }

    @discardableResult
    static func writeData(_ data: Data) -> Bool {
        let sharedDefaults = defaults
        sharedDefaults.set(data, forKey: storageKey)

        let didWriteFile: Bool
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(snapshotFileName) {
            do {
                try data.write(to: url, options: .atomic)
                didWriteFile = true
            } catch {
                didWriteFile = false
            }
        } else {
            didWriteFile = false
        }

        return didWriteFile || UserDefaults(suiteName: appGroupID) != nil
    }
}

struct EnergyHabit: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var symbol: String
    var colorHex: String
    var isEnabled: Bool
    var isFavorite: Bool
    var isArchived: Bool
    var category: EnergyHabitCategory

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        colorHex: String,
        isEnabled: Bool = true,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        category: EnergyHabitCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.isEnabled = isEnabled
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.category = category ?? Self.inferredCategory(for: name)
    }

    var localizedName: String {
        NSLocalizedString(name, comment: "Default energy habit name")
    }

    private static func inferredCategory(for name: String) -> EnergyHabitCategory {
        if ["伸懒腰", "泡脚", "泡澡", "深呼吸", "早睡", "睡午觉", "洗澡", "喝水"].contains(name) { return .body }
        if ["晒太阳", "逛公园", "散步", "看日落", "看云", "观鸟", "爬山", "骑行"].contains(name) { return .nature }
        if ["整理家里", "整理桌面", "晒被子", "换上干净床单", "点香薰", "给植物浇水", "断舍离", "做饭"].contains(name) { return .home }
        if ["阅读", "冥想", "喝茶", "写日记", "听雨", "听歌", "独处", "放下手机", "练字"].contains(name) { return .quiet }
        if ["画画", "做手工", "拼图", "烘焙", "唱歌", "跳舞", "穿漂亮衣服", "整理相册"].contains(name) { return .create }
        if ["拥抱", "联系朋友", "撸猫", "大笑", "夸夸自己", "逛菜市场", "逛博物馆", "吃水果", "早起"].contains(name) { return .connection }
        return .personal
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, symbol, colorHex, isEnabled, isFavorite, isArchived, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        category = try container.decodeIfPresent(EnergyHabitCategory.self, forKey: .category)
            ?? Self.inferredCategory(for: name)
    }
}

enum EnergyHabitCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case body, nature, home, quiet, create, connection, personal

    var id: Self { self }
    var title: String {
        switch self {
        case .body: String(localized: "身体放松")
        case .nature: String(localized: "自然充电")
        case .home: String(localized: "居家治愈")
        case .quiet: String(localized: "安静独处")
        case .create: String(localized: "快乐创造")
        case .connection: String(localized: "温暖连接")
        case .personal: String(localized: "我的小事")
        }
    }
    var symbol: String {
        switch self {
        case .body: "figure.flexibility"
        case .nature: "leaf.fill"
        case .home: "house.fill"
        case .quiet: "moon.stars.fill"
        case .create: "paintpalette.fill"
        case .connection: "heart.fill"
        case .personal: "sparkles"
        }
    }
}

struct DailyEnergyRecord: Codable, Equatable, Sendable {
    var completedHabitIDs: Set<UUID> = []
}

struct CompletionChange: Codable, Equatable, Sendable {
    var isCompleted: Bool
    var updatedAt: Date
}

struct PersistedEnergyData: Codable, Sendable {
    var habits: [EnergyHabit]
    var records: [String: DailyEnergyRecord]
    var completionChanges: [String: [UUID: CompletionChange]]
    var updatedAt: Date

    init(
        habits: [EnergyHabit],
        records: [String: DailyEnergyRecord],
        completionChanges: [String: [UUID: CompletionChange]] = [:],
        updatedAt: Date = .now
    ) {
        self.habits = habits
        self.records = records
        self.completionChanges = completionChanges
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case habits, records, completionChanges, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        habits = try container.decode([EnergyHabit].self, forKey: .habits)
        records = try container.decode([String: DailyEnergyRecord].self, forKey: .records)
        completionChanges = try container.decodeIfPresent(
            [String: [UUID: CompletionChange]].self,
            forKey: .completionChanges
        ) ?? [:]
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }

    mutating func recordCompletionChange(habitID: UUID, dayID: String, isCompleted: Bool, at date: Date = .now) {
        completionChanges[dayID, default: [:]][habitID] = CompletionChange(
            isCompleted: isCompleted,
            updatedAt: date
        )
    }

    static func merged(_ local: Self, _ remote: Self) -> Self {
        let habits = local.updatedAt >= remote.updatedAt ? local.habits : remote.habits
        var changes = normalizedChanges(for: remote)
        for (dayID, localDayChanges) in normalizedChanges(for: local) {
            for (habitID, localChange) in localDayChanges {
                if let remoteChange = changes[dayID]?[habitID], remoteChange.updatedAt > localChange.updatedAt {
                    continue
                }
                changes[dayID, default: [:]][habitID] = localChange
            }
        }

        var records: [String: DailyEnergyRecord] = [:]
        for (dayID, dayChanges) in changes {
            let completed = Set(dayChanges.compactMap { $0.value.isCompleted ? $0.key : nil })
            if !completed.isEmpty { records[dayID] = DailyEnergyRecord(completedHabitIDs: completed) }
        }
        return Self(
            habits: habits,
            records: records,
            completionChanges: changes,
            updatedAt: max(local.updatedAt, remote.updatedAt)
        )
    }

    private static func normalizedChanges(for payload: Self) -> [String: [UUID: CompletionChange]] {
        var result = payload.completionChanges
        let fallbackDate = payload.updatedAt == .distantPast ? Date(timeIntervalSince1970: 0) : payload.updatedAt
        for (dayID, record) in payload.records {
            for habitID in record.completedHabitIDs where result[dayID]?[habitID] == nil {
                result[dayID, default: [:]][habitID] = CompletionChange(
                    isCompleted: true,
                    updatedAt: fallbackDate
                )
            }
        }
        return result
    }
}

extension Date {
    var energyDayID: String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}
