import AppIntents
import SwiftUI
import WidgetKit

private enum WidgetPalette {
    static let rose = Color(red: 0.957, green: 0.373, blue: 0.478)
    static let cocoa = Color(red: 0.29, green: 0.157, blue: 0.157)
    static let blush = Color(red: 1.0, green: 0.941, blue: 0.949)
    static let card = Color.white.opacity(0.74)
}

struct EnergyWidgetEntry: TimelineEntry {
    let date: Date
    let completedCount: Int
    let habits: [EnergyHabit]
    let completedIDs: Set<UUID>
    let isSynced: Bool
}

struct EnergyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> EnergyWidgetEntry {
        let habits = previewHabits
        return EnergyWidgetEntry(date: .now, completedCount: 4, habits: habits, completedIDs: Set(habits.prefix(2).map(\.id)), isSynced: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (EnergyWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EnergyWidgetEntry>) -> Void) {
        let now = Date.now
        let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0), matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        let recoveryRefresh = now.addingTimeInterval(5 * 60)
        completion(Timeline(entries: [currentEntry(at: now)], policy: .after(min(midnight, recoveryRefresh))))
    }

    private func currentEntry(at date: Date = .now) -> EnergyWidgetEntry {
        guard let data = EnergyShared.readWidgetData(),
              let payload = try? JSONDecoder().decode(PersistedEnergyData.self, from: data) else {
            return EnergyWidgetEntry(date: date, completedCount: 0, habits: previewHabits, completedIDs: [], isSynced: false)
        }
        let enabledHabits = payload.habits.filter { $0.isEnabled && !$0.isArchived }
        let favorites = enabledHabits.filter(\.isFavorite)
        let displayedHabits = favorites.isEmpty ? enabledHabits : favorites
        let validIDs = Set(payload.habits.map(\.id))
        let completed = payload.records[date.energyDayID]?.completedHabitIDs.intersection(validIDs) ?? []
        return EnergyWidgetEntry(
            date: date,
            completedCount: completed.count,
            habits: Array(displayedHabits.prefix(4)),
            completedIDs: completed,
            isSynced: true
        )
    }

    private var previewHabits: [EnergyHabit] {
        [
            EnergyHabit(name: "晒太阳", symbol: "sun.max.fill", colorHex: "F5A524"),
            EnergyHabit(name: "睡午觉", symbol: "bed.double.fill", colorHex: "8FBB75"),
            EnergyHabit(name: "伸懒腰", symbol: "figure.flexibility", colorHex: "9A82DE"),
            EnergyHabit(name: "听歌", symbol: "music.note", colorHex: "F45F7A")
        ]
    }
}

struct SmallEnergyWidgetView: View {
    let entry: EnergyWidgetEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WidgetPalette.blush, WidgetPalette.rose.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image("SmallWidgetBackground", bundle: .main)
                .renderingMode(.original)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text("今日元气")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetPalette.rose)
                Text("\(entry.completedCount)")
                    .font(.system(size: 43, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetPalette.rose)
                Spacer(minLength: 4)
                Text("\(entry.completedCount)次小胜利")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetPalette.cocoa)
                Text(entry.date.formatted(.dateTime.month().day()))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .unredacted()
        .containerBackground(for: .widget) {
            LinearGradient(colors: [WidgetPalette.blush, WidgetPalette.rose.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct MediumEnergyWidgetView: View {
    let entry: EnergyWidgetEntry

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Text("元气小事")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetPalette.cocoa)
                Spacer()
                Text("今日 +\(entry.completedCount)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetPalette.rose)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                ForEach(Array(entry.habits.prefix(4))) { habit in
                    if entry.isSynced {
                        Button(intent: ToggleWidgetHabitIntent(habitID: habit.id)) {
                            habitTile(habit)
                        }
                        .buttonStyle(.plain)
                    } else {
                        habitTile(habit).opacity(0.55)
                    }
                }
            }

            Button(intent: OpenYuanQiAppIntent()) {
                HStack {
                    Spacer()
                    Text(
                        entry.isSynced
                            ? String(localized: "打开 App 查看全部")
                            : String(localized: "打开 App 完成同步")
                    )
                    Image(systemName: "chevron.right")
                    Spacer()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WidgetPalette.cocoa.opacity(0.82))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 1, green: 0.975, blue: 0.965), WidgetPalette.blush], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func habitTile(_ habit: EnergyHabit) -> some View {
        let completed = entry.completedIDs.contains(habit.id)
        return HStack(spacing: 6) {
            Image(systemName: habit.symbol)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 15))
                .foregroundStyle(Color(widgetHex: habit.colorHex))
                .frame(width: 27, height: 27)
                .background(Color(widgetHex: habit.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(habit.localizedName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetPalette.cocoa)
                    .lineLimit(1)
                if completed {
                    Text("+1").font(.system(size: 9, weight: .semibold)).foregroundStyle(WidgetPalette.rose)
                }
            }
            Spacer(minLength: 2)
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(completed ? WidgetPalette.rose : WidgetPalette.rose.opacity(0.45))
        }
        .padding(.horizontal, 7)
        .frame(height: 44)
        .background(completed ? WidgetPalette.blush : WidgetPalette.card, in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11).stroke(WidgetPalette.rose.opacity(0.12), lineWidth: 0.8)
        }
    }
}

struct YuanQiWidget: Widget {
    static let kind = EnergyWidgetInteraction.widgetKind
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: EnergyWidgetProvider()) { entry in
            WidgetFamilyView(entry: entry)
        }
            .configurationDisplayName("元气小事")
            .description("看看今天积累了多少元气和小胜利。")
            .supportedFamilies([.systemSmall, .systemMedium])
            .contentMarginsDisabled()
            .containerBackgroundRemovable(false)
    }
}

private struct WidgetFamilyView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EnergyWidgetEntry
    var body: some View {
        switch family {
        case .systemMedium: MediumEnergyWidgetView(entry: entry)
        default: SmallEnergyWidgetView(entry: entry)
        }
    }
}

@main
struct YuanQiWidgetBundle: WidgetBundle {
    var body: some Widget { YuanQiWidget() }
}

private extension Color {
    init(widgetHex: String) {
        var value: UInt64 = 0
        Scanner(string: widgetHex).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
