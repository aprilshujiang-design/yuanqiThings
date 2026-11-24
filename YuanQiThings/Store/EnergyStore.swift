import Foundation
import SwiftUI
import WidgetKit
import CloudKit

enum CloudSyncState: Equatable {
    case checking
    case syncing
    case synced(Date)
    case signedOut
    case unavailable
    case failed(String)

    var title: String {
        switch self {
        case .checking: String(localized: "正在检查 iCloud")
        case .syncing: String(localized: "正在同步")
        case .synced: String(localized: "已同步到 iCloud")
        case .signedOut: String(localized: "未登录 iCloud")
        case .unavailable: String(localized: "iCloud 暂不可用")
        case .failed: String(localized: "同步失败")
        }
    }

    var symbol: String {
        switch self {
        case .checking, .syncing: "arrow.triangle.2.circlepath.icloud"
        case .synced: "checkmark.icloud.fill"
        case .signedOut: "person.crop.circle.badge.exclamationmark"
        case .unavailable, .failed: "exclamationmark.icloud.fill"
        }
    }
}

private struct EnergyLoadResult: Sendable {
    let data: Data?
    let payload: PersistedEnergyData?
    let legacySeedVersion: Int?
}

@MainActor
final class EnergyStore: ObservableObject {
    @Published private(set) var habits: [EnergyHabit] = EnergyStore.defaults
    @Published private(set) var records: [String: DailyEnergyRecord] = [:]
    @Published private(set) var isReady = false
    @Published private(set) var cloudSyncState: CloudSyncState = .checking

    private let currentSeedVersion = 4
    private lazy var storageDefaults = EnergyShared.defaults
    private var hasLoaded = false
    private var isLoading = false
    private var currentUpdatedAt = Date.distantPast
    private var completionChanges: [String: [UUID: CompletionChange]] = [:]
    private var cloudSyncTask: Task<Void, Never>?

    func start() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadInBackground()
    }

    var enabledHabits: [EnergyHabit] { habits.filter { $0.isEnabled && !$0.isArchived } }
    var visibleHabits: [EnergyHabit] { habits.filter { !$0.isArchived } }
    var favoriteHabits: [EnergyHabit] { enabledHabits.filter(\.isFavorite) }

    func reloadFromSharedStorage() {
        guard hasLoaded else { return }
        loadInBackground()
    }

    func completedCount(on date: Date) -> Int {
        guard let completedIDs = records[date.energyDayID]?.completedHabitIDs else { return 0 }
        let knownIDs = Set(habits.map(\.id))
        return completedIDs.intersection(knownIDs).count
    }

    func isCompleted(_ habit: EnergyHabit, on date: Date) -> Bool {
        records[date.energyDayID]?.completedHabitIDs.contains(habit.id) == true
    }

    @discardableResult
    func toggle(_ habit: EnergyHabit, on date: Date) -> Bool {
        guard isReady else { return false }
        let dayID = date.energyDayID
        var record = records[dayID] ?? DailyEnergyRecord()
        let didComplete: Bool
        if record.completedHabitIDs.contains(habit.id) {
            record.completedHabitIDs.remove(habit.id)
            didComplete = false
        } else {
            record.completedHabitIDs.insert(habit.id)
            didComplete = true
        }
        if record.completedHabitIDs.isEmpty {
            records.removeValue(forKey: dayID)
        } else {
            records[dayID] = record
        }
        completionChanges[dayID, default: [:]][habit.id] = CompletionChange(
            isCompleted: didComplete,
            updatedAt: .now
        )
        save()
        return didComplete
    }

    func add(_ habit: EnergyHabit) {
        habits.append(habit)
        save()
    }

    func update(_ habit: EnergyHabit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index] = habit
        save()
    }

    func toggleFavorite(_ habit: EnergyHabit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        if !habits[index].isFavorite, favoriteHabits.count >= 8 { return }
        habits[index].isFavorite.toggle()
        save()
    }

    func toggleEnabled(_ habit: EnergyHabit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].isEnabled.toggle()
        if !habits[index].isEnabled { habits[index].isFavorite = false }
        save()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets where habits.indices.contains(index) {
            habits[index].isArchived = true
            habits[index].isEnabled = false
            habits[index].isFavorite = false
        }
        save()
    }

    func delete(_ habit: EnergyHabit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].isArchived = true
        habits[index].isEnabled = false
        habits[index].isFavorite = false
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func makeBackupData() throws -> Data {
        let payload = PersistedEnergyData(
            habits: habits,
            records: records,
            completionChanges: completionChanges,
            updatedAt: currentUpdatedAt == .distantPast ? .now : currentUpdatedAt
        )
        return try JSONEncoder().encode(payload)
    }

    func restoreBackup(from data: Data) throws {
        let payload = try JSONDecoder().decode(PersistedEnergyData.self, from: data)
        habits = payload.habits
        records = payload.records
        completionChanges = payload.completionChanges
        pruneOrphanedCompletions()
        save()
    }

    func monthlyWins(containing date: Date) -> Int {
        guard let interval = Calendar.current.dateInterval(of: .month, for: date) else { return 0 }
        return records.reduce(into: 0) { result, pair in
            guard let day = Self.dayFormatter.date(from: pair.key), interval.contains(day) else { return }
            result += completedCount(on: day)
        }
    }

    func currentStreak(ending date: Date = .now) -> Int {
        var streak = 0
        var day = Calendar.current.startOfDay(for: date)
        while completedCount(on: day) > 0 {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    func longestStreak(containing date: Date) -> Int {
        guard let interval = Calendar.current.dateInterval(of: .month, for: date) else { return 0 }
        var longest = 0
        var running = 0
        var day = interval.start

        while day < interval.end {
            if completedCount(on: day) > 0 {
                running += 1
                longest = max(longest, running)
            } else {
                running = 0
            }

            guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return longest
    }

    func weeklyWins(containing date: Date = .now) -> Int {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return records.reduce(into: 0) { result, pair in
            guard let day = Self.dayFormatter.date(from: pair.key), interval.contains(day) else { return }
            result += completedCount(on: day)
        }
    }

    private func loadInBackground() {
        guard !isLoading else { return }
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = Self.loadSnapshot()
            await self?.apply(result)
            await self?.reconcileWithCloud(hadLocalData: result.payload != nil)
        }
    }

    private nonisolated static func loadSnapshot() -> EnergyLoadResult {
        if let data = EnergyShared.readData() {
            return EnergyLoadResult(
                data: data,
                payload: try? JSONDecoder().decode(PersistedEnergyData.self, from: data),
                legacySeedVersion: nil
            )
        }
        if let legacyData = UserDefaults.standard.data(forKey: EnergyShared.storageKey) {
            return EnergyLoadResult(
                data: legacyData,
                payload: try? JSONDecoder().decode(PersistedEnergyData.self, from: legacyData),
                legacySeedVersion: UserDefaults.standard.integer(forKey: EnergyShared.seedVersionKey)
            )
        }
        return EnergyLoadResult(data: nil, payload: nil, legacySeedVersion: nil)
    }

    private func apply(_ result: EnergyLoadResult) {
        isLoading = false
        if let data = result.data, let decoded = result.payload {
            // The widget must not reload before the shared snapshot is complete.
            EnergyShared.writeData(data)
            if let legacySeedVersion = result.legacySeedVersion {
                storageDefaults.set(legacySeedVersion, forKey: EnergyShared.seedVersionKey)
            }
            habits = decoded.habits
            records = decoded.records
            completionChanges = decoded.completionChanges
            currentUpdatedAt = decoded.updatedAt
            migrateSeedDataIfNeeded()
            pruneOrphanedCompletions()
            refreshWidget()
        } else {
            habits = Self.defaults
            storageDefaults.set(currentSeedVersion, forKey: EnergyShared.seedVersionKey)
            let payload = PersistedEnergyData(habits: habits, records: records)
            currentUpdatedAt = payload.updatedAt
            if let data = try? JSONEncoder().encode(payload) {
                EnergyShared.writeData(data)
                WidgetCenter.shared.reloadTimelines(ofKind: EnergyWidgetInteraction.widgetKind)
            }
        }
        isReady = true
    }

    private func migrateSeedDataIfNeeded() {
        guard storageDefaults.integer(forKey: EnergyShared.seedVersionKey) < currentSeedVersion else { return }
        let existingNames = Set(habits.map(\.name))
        habits.append(contentsOf: Self.newEnergyHabits.filter { !existingNames.contains($0.name) })
        habits = habits.map { habit in
            guard habit.symbol == "wateringcan.fill" else { return habit }
            var updated = habit
            updated.symbol = "drop.fill"
            return updated
        }
        storageDefaults.set(currentSeedVersion, forKey: EnergyShared.seedVersionKey)
        save()
    }

    private func pruneOrphanedCompletions() {
        let validIDs = Set(habits.map(\.id))
        var didChange = false

        for dayID in Array(records.keys) {
            guard var record = records[dayID] else { continue }
            let validCompletions = record.completedHabitIDs.intersection(validIDs)
            guard validCompletions != record.completedHabitIDs else { continue }
            didChange = true
            record.completedHabitIDs = validCompletions
            if validCompletions.isEmpty {
                records.removeValue(forKey: dayID)
            } else {
                records[dayID] = record
            }
        }

        if didChange { save() }
    }

    private func save() {
        let payload = PersistedEnergyData(
            habits: habits,
            records: records,
            completionChanges: completionChanges
        )
        currentUpdatedAt = payload.updatedAt
        if let data = try? JSONEncoder().encode(payload) {
            EnergyShared.writeData(data)
            refreshWidget()
            scheduleCloudSync(data)
        }
    }

    private func reconcileWithCloud(hadLocalData: Bool) async {
        do {
            if !hadLocalData,
               let remoteData = try await CloudSyncService.shared.download(),
               let remote = try? JSONDecoder().decode(PersistedEnergyData.self, from: remoteData) {
                habits = remote.habits
                records = remote.records
                completionChanges = remote.completionChanges
                currentUpdatedAt = remote.updatedAt
                EnergyShared.writeData(remoteData)
                migrateSeedDataIfNeeded()
                pruneOrphanedCompletions()
                refreshWidget()
            }
            let localPayload = PersistedEnergyData(
                habits: habits,
                records: records,
                completionChanges: completionChanges,
                updatedAt: currentUpdatedAt == .distantPast ? .now : currentUpdatedAt
            )
            if let data = try? JSONEncoder().encode(localPayload) {
                cloudSyncState = .syncing
                let mergedData = try await CloudSyncService.shared.mergeAndUpload(data)
                applyCloudData(mergedData)
                cloudSyncState = .synced(.now)
            }
        } catch {
            cloudSyncState = syncState(for: error)
        }
    }

    func syncCloudNow() {
        guard isReady else { return }
        let payload = PersistedEnergyData(
            habits: habits,
            records: records,
            completionChanges: completionChanges,
            updatedAt: currentUpdatedAt == .distantPast ? .now : currentUpdatedAt
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        scheduleCloudSync(data, delay: false)
    }

    private func scheduleCloudSync(_ data: Data, delay: Bool = true) {
        cloudSyncTask?.cancel()
        cloudSyncState = .syncing
        cloudSyncTask = Task { [weak self] in
            if delay { try? await Task.sleep(for: .milliseconds(450)) }
            guard !Task.isCancelled else { return }
            do {
                let mergedData = try await CloudSyncService.shared.mergeAndUpload(data)
                guard !Task.isCancelled else { return }
                self?.applyCloudData(mergedData)
                self?.cloudSyncState = .synced(.now)
            } catch {
                guard !Task.isCancelled else { return }
                self?.cloudSyncState = self?.syncState(for: error) ?? .failed(String(localized: "未知错误"))
            }
        }
    }

    private func applyCloudData(_ data: Data) {
        guard let cloudPayload = try? JSONDecoder().decode(PersistedEnergyData.self, from: data) else { return }
        let localPayload = PersistedEnergyData(
            habits: habits,
            records: records,
            completionChanges: completionChanges,
            updatedAt: currentUpdatedAt
        )
        let merged = PersistedEnergyData.merged(localPayload, cloudPayload)
        habits = merged.habits
        records = merged.records
        completionChanges = merged.completionChanges
        currentUpdatedAt = merged.updatedAt
        if let encoded = try? JSONEncoder().encode(merged) { EnergyShared.writeData(encoded) }
        EnergyShared.defaults.set(false, forKey: EnergyShared.widgetSyncPendingKey)
        refreshWidget()
    }

    private func syncState(for error: Error) -> CloudSyncState {
        if case CloudSyncService.SyncError.unavailable(let status) = error {
            return status == .noAccount ? .signedOut : .unavailable
        }
        if let cloudError = error as? CKError,
           [.notAuthenticated, .permissionFailure].contains(cloudError.code) {
            return .signedOut
        }
        return .failed(Self.cloudErrorMessage(error))
    }

    private static func cloudErrorMessage(_ error: Error) -> String {
        if let syncError = error as? CloudSyncService.SyncError {
            return syncError.localizedDescription
        }
        guard let cloudError = error as? CKError else {
            return String(localized: "无法连接 iCloud，请稍后重试")
        }
        switch cloudError.code {
        case .networkUnavailable, .networkFailure:
            return String(localized: "网络不可用，请检查连接后重试")
        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return String(localized: "iCloud 服务繁忙，请稍后重试")
        case .quotaExceeded:
            return String(localized: "iCloud 可用空间不足")
        case .permissionFailure, .notAuthenticated:
            return String(localized: "当前安装包没有 iCloud 访问权限，请检查签名与容器配置")
        case .serverRejectedRequest, .invalidArguments:
            return String(localized: "iCloud 数据库尚未正确配置，请部署 CloudKit 生产环境")
        case .assetFileNotFound, .assetFileModified:
            return String(localized: "同步文件已变更，请再次同步")
        default:
            return String(localized: "iCloud 错误（\(cloudError.code.rawValue)），请稍后重试")
        }
    }

    func syncWidgetNow() {
        Task.detached(priority: .userInitiated) {
            WidgetCenter.shared.reloadTimelines(ofKind: EnergyWidgetInteraction.widgetKind)
        }
    }

    private func refreshWidget() {
        syncWidgetNow()
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let originalHabits = [
        EnergyHabit(name: "早起", symbol: "sun.max.fill", colorHex: "F5A524"),
        EnergyHabit(name: "阅读", symbol: "book.closed.fill", colorHex: "72A95A"),
        EnergyHabit(name: "冥想", symbol: "figure.mind.and.body", colorHex: "9675D8"),
        EnergyHabit(name: "逛公园", symbol: "tree.fill", colorHex: "6A9F59"),
        EnergyHabit(name: "泡脚", symbol: "drop.fill", colorHex: "F17582"),
        EnergyHabit(name: "练字", symbol: "pencil.and.scribble", colorHex: "5C8FD6"),
        EnergyHabit(name: "整理家里", symbol: "house.fill", colorHex: "E5A34A")
    ]

    static let newEnergyHabits = [
        EnergyHabit(name: "晒太阳", symbol: "sun.max.fill", colorHex: "F5A524"),
        EnergyHabit(name: "睡午觉", symbol: "bed.double.fill", colorHex: "9A82DE"),
        EnergyHabit(name: "伸懒腰", symbol: "figure.flexibility", colorHex: "FF9D69"),
        EnergyHabit(name: "听歌", symbol: "headphones", colorHex: "9A82DE"),
        EnergyHabit(name: "听雨", symbol: "cloud.rain.fill", colorHex: "67B8C4"),
        EnergyHabit(name: "撸猫", symbol: "cat.fill", colorHex: "E88BB7"),
        EnergyHabit(name: "洗澡", symbol: "shower.fill", colorHex: "67B8C4"),
        EnergyHabit(name: "画画", symbol: "paintpalette.fill", colorHex: "F45F7A"),
        EnergyHabit(name: "给植物浇水", symbol: "drop.fill", colorHex: "8FBB75"),
        EnergyHabit(name: "穿漂亮衣服", symbol: "tshirt.fill", colorHex: "E88BB7"),
        EnergyHabit(name: "喝茶", symbol: "cup.and.saucer.fill", colorHex: "E5A34A"),
        EnergyHabit(name: "深呼吸", symbol: "wind", colorHex: "67B8C4"),
        EnergyHabit(name: "做饭", symbol: "fork.knife", colorHex: "FF9D69"),
        EnergyHabit(name: "爬山", symbol: "mountain.2.fill", colorHex: "8FBB75"),
        EnergyHabit(name: "大笑", symbol: "face.smiling.fill", colorHex: "FFC857"),
        EnergyHabit(name: "逛菜市场", symbol: "basket.fill", colorHex: "FF8D9C"),
        EnergyHabit(name: "逛博物馆", symbol: "building.columns.fill", colorHex: "9A82DE"),
        EnergyHabit(name: "写日记", symbol: "book.pages.fill", colorHex: "5C8FD6"),
        EnergyHabit(name: "晒被子", symbol: "bed.double.fill", colorHex: "FFC857"),
        EnergyHabit(name: "断舍离", symbol: "arrow.triangle.2.circlepath", colorHex: "67B8C4"),
        EnergyHabit(name: "独处", symbol: "person.fill", colorHex: "9A82DE"),
        EnergyHabit(name: "观鸟", symbol: "bird.fill", colorHex: "8FBB75"),
        EnergyHabit(name: "泡澡", symbol: "bathtub.fill", colorHex: "E88BB7"),
        EnergyHabit(name: "散步", symbol: "figure.walk", colorHex: "8FBB75"),
        EnergyHabit(name: "喝水", symbol: "waterbottle.fill", colorHex: "67B8C4"),
        EnergyHabit(name: "吃水果", symbol: "carrot.fill", colorHex: "FF9D69"),
        EnergyHabit(name: "整理桌面", symbol: "square.grid.2x2.fill", colorHex: "5C8FD6"),
        EnergyHabit(name: "点香薰", symbol: "flame.fill", colorHex: "E88BB7"),
        EnergyHabit(name: "看日落", symbol: "sunset.fill", colorHex: "FF8D9C"),
        EnergyHabit(name: "看云", symbol: "cloud.fill", colorHex: "67B8C4"),
        EnergyHabit(name: "拥抱", symbol: "heart.fill", colorHex: "F45F7A"),
        EnergyHabit(name: "联系朋友", symbol: "message.fill", colorHex: "72A95A"),
        EnergyHabit(name: "做手工", symbol: "scissors", colorHex: "9A82DE"),
        EnergyHabit(name: "拼图", symbol: "puzzlepiece.extension.fill", colorHex: "FFC857"),
        EnergyHabit(name: "烘焙", symbol: "birthday.cake.fill", colorHex: "E5A34A"),
        EnergyHabit(name: "唱歌", symbol: "music.mic", colorHex: "E88BB7"),
        EnergyHabit(name: "跳舞", symbol: "figure.dance", colorHex: "F45F7A"),
        EnergyHabit(name: "骑行", symbol: "bicycle", colorHex: "8FBB75"),
        EnergyHabit(name: "整理相册", symbol: "photo.on.rectangle.angled", colorHex: "9A82DE"),
        EnergyHabit(name: "换上干净床单", symbol: "bed.double.fill", colorHex: "67B8C4"),
        EnergyHabit(name: "放下手机", symbol: "iphone.slash", colorHex: "5C8FD6"),
        EnergyHabit(name: "早睡", symbol: "moon.zzz.fill", colorHex: "9A82DE"),
        EnergyHabit(name: "夸夸自己", symbol: "hands.sparkles.fill", colorHex: "FFC857")
    ]

    static let defaults: [EnergyHabit] = {
        var habits = originalHabits + newEnergyHabits
        for index in habits.indices.prefix(8) { habits[index].isFavorite = true }
        return habits
    }()
}
