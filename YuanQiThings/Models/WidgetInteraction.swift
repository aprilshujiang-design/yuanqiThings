import AppIntents
import Foundation
import WidgetKit

enum EnergyWidgetInteraction {
    static let widgetKind = "YuanQiEnergyWidgetV2"

    static func toggle(habitID: UUID, at date: Date = .now) -> Data? {
        guard let data = EnergyShared.readData(),
              var payload = try? JSONDecoder().decode(PersistedEnergyData.self, from: data),
              payload.habits.contains(where: { $0.id == habitID && $0.isEnabled && !$0.isArchived }) else {
            return nil
        }

        let dayID = date.energyDayID
        var record = payload.records[dayID] ?? DailyEnergyRecord()
        if record.completedHabitIDs.contains(habitID) {
            record.completedHabitIDs.remove(habitID)
        } else {
            record.completedHabitIDs.insert(habitID)
        }
        let isCompleted = record.completedHabitIDs.contains(habitID)
        if record.completedHabitIDs.isEmpty {
            payload.records.removeValue(forKey: dayID)
        } else {
            payload.records[dayID] = record
        }
        payload.recordCompletionChange(
            habitID: habitID,
            dayID: dayID,
            isCompleted: isCompleted
        )
        payload.updatedAt = .now

        guard let encoded = try? JSONEncoder().encode(payload),
              EnergyShared.writeData(encoded) else { return nil }
        EnergyShared.defaults.set(true, forKey: EnergyShared.widgetSyncPendingKey)
        return encoded
    }
}

struct ToggleWidgetHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "记录元气小事"
    static let description = IntentDescription("在桌面小组件中记录或取消一件元气小事")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "小事 ID") var habitID: String

    init() { habitID = "" }
    init(habitID: UUID) { self.habitID = habitID.uuidString }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habitID),
              let localData = EnergyWidgetInteraction.toggle(habitID: id) else {
            return .result()
        }
        WidgetCenter.shared.reloadTimelines(ofKind: EnergyWidgetInteraction.widgetKind)
        do {
            let mergedData = try await CloudSyncService.shared.mergeAndUpload(localData)
            EnergyShared.writeData(mergedData)
            EnergyShared.defaults.set(false, forKey: EnergyShared.widgetSyncPendingKey)
            WidgetCenter.shared.reloadTimelines(ofKind: EnergyWidgetInteraction.widgetKind)
        } catch {
            // The containing app retries the pending change the next time it becomes active.
        }
        return .result()
    }
}

struct OpenYuanQiAppIntent: AppIntent {
    static let title: LocalizedStringResource = "打开元气小事"
    static let openAppWhenRun = true
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        .result()
    }
}
