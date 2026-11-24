import SwiftUI
import UIKit

struct TodayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum MomentNeed: String, CaseIterable, Identifiable {
        case relax, recharge, quiet, outdoors, fun
        var id: Self { self }
        var title: String {
            switch self {
            case .relax: String(localized: "放松一下")
            case .recharge: String(localized: "找回精神")
            case .quiet: String(localized: "安静独处")
            case .outdoors: String(localized: "出门走走")
            case .fun: String(localized: "做点有趣的事")
            }
        }
        var symbol: String {
            switch self {
            case .relax: "leaf.fill"
            case .recharge: "bolt.fill"
            case .quiet: "moon.stars.fill"
            case .outdoors: "figure.walk"
            case .fun: "paintpalette.fill"
            }
        }
        var categories: [EnergyHabitCategory] {
            switch self {
            case .relax: [.body, .quiet]
            case .recharge: [.nature, .body]
            case .quiet: [.quiet]
            case .outdoors: [.nature]
            case .fun: [.create, .connection]
            }
        }
    }

    @EnvironmentObject private var store: EnergyStore
    @AppStorage("yuanqi.haptics.enabled") private var hapticsEnabled = true
    @State private var celebratingHabitID: UUID?
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var showingDatePicker = false
    @State private var hasLoadedBackground = false
    @State private var showingMoreHabits = false
    @State private var firstWinCelebrating = false
    @State private var selectedMomentNeed: MomentNeed?
    @State private var today = Calendar.current.startOfDay(for: .now)
    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var completed: Int { store.completedCount(on: selectedDate) }
    private var isToday: Bool { Calendar.current.isDate(selectedDate, inSameDayAs: today) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.blush, AppTheme.cream],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if hasLoadedBackground {
                Image("TodayBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }

            ScrollView {
                VStack(spacing: 16) {
                    header
                    weekStrip
                    if !isToday { backfillBanner }
                    heroProgress
                    momentAndHabitHeader

                    if primaryHabits.isEmpty {
                        SoftCard {
                            GentleEmptyState(
                                symbol: "heart.text.clipboard",
                                title: "这里先留一点空白",
                                message: "去“小事”页选几件喜欢的，想记录时它们就在这里"
                            )
                            .padding(.vertical, 8)
                        }
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(primaryHabits) { habit in
                                habitCard(habit)
                            }
                        }
                    }

                    if showingMoreHabits {
                        moreHabitsByCategory
                            .transaction { transaction in
                                transaction.animation = nil
                                transaction.disablesAnimations = true
                            }
                    }

                    summaryCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .task {
            guard !hasLoadedBackground else { return }
            await Task.yield()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                hasLoadedBackground = true
            }
        }
        .task { await watchForNewDay() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshToday()
        }
        .sheet(isPresented: $showingDatePicker) {
            CheckInDatePicker(selection: $selectedDate, latestDate: today)
                .presentationDetents([.large])
        }
        .onChange(of: selectedDate) {
            celebratingHabitID = nil
            firstWinCelebrating = false
            showingMoreHabits = false
            selectedMomentNeed = nil
        }
        .navigationBarHidden(true)
    }

    private var heroProgress: some View {
        Color.clear
            .frame(height: 188)
            .overlay {
                if firstWinCelebrating {
                    FirstWinCelebration()
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                Text(energyTitle)
                    .font(.headline)
                    .foregroundStyle(AppTheme.rose)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.9), in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.rose.opacity(0.35)))
                    .shadow(color: AppTheme.rose.opacity(0.12), radius: 8, y: 4)
            }
    }

    private var moreHabits: [EnergyHabit] {
        let primaryIDs = Set(primaryHabits.map(\.id))
        return store.enabledHabits.filter { !primaryIDs.contains($0.id) }
    }

    private var momentAndHabitHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(
                    isToday
                        ? String(localized: "此刻想做点什么？")
                        : String(localized: "想为这一天记录什么？")
                )
                    .font(.headline)
                    .foregroundStyle(AppTheme.cocoa)
                Spacer()
                if !moreHabits.isEmpty {
                    Button {
                        var transaction = Transaction(animation: nil)
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { showingMoreHabits.toggle() }
                    } label: {
                        Label(
                            showingMoreHabits ? String(localized: "收起") : String(localized: "更多小事"),
                            systemImage: showingMoreHabits ? "chevron.up" : "sparkles"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.rose)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.82), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(MomentNeed.allCases) { need in
                        Button {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                                selectedMomentNeed = selectedMomentNeed == need ? nil : need
                            }
                            showingMoreHabits = false
                        } label: {
                            Label(need.title, systemImage: need.symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedMomentNeed == need ? .white : AppTheme.cocoa)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(selectedMomentNeed == need ? AppTheme.rose : .white.opacity(0.82), in: Capsule())
                                .overlay { Capsule().stroke(AppTheme.rose.opacity(selectedMomentNeed == need ? 0 : 0.16)) }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)

            if selectedMomentNeed != nil {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                    Text("已为你轻轻筛选")
                    Spacer()
                    Button("回到常用") {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                            selectedMomentNeed = nil
                        }
                    }
                    .fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.rose)
            }
        }
        .padding(14)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.86)) }
    }

    private var primaryHabits: [EnergyHabit] {
        guard let selectedMomentNeed else { return Array(store.favoriteHabits.prefix(8)) }
        let matches = selectedMomentNeed.categories.flatMap { category in
            store.enabledHabits.filter { $0.category == category }
        }
        var seen = Set<UUID>()
        let uniqueMatches = matches.filter { seen.insert($0.id).inserted }
        if uniqueMatches.count >= 4 { return Array(uniqueMatches.prefix(4)) }
        let fallback = store.favoriteHabits.filter { seen.insert($0.id).inserted }
        return Array((uniqueMatches + fallback).prefix(4))
    }

    private var moreHabitsByCategory: some View {
        LazyVStack(spacing: 18) {
            ForEach(EnergyHabitCategory.allCases) { category in
                let habits = moreHabits.filter { $0.category == category }
                if !habits.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(category.title, systemImage: category.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.cocoa.opacity(0.82))
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(habits) { habit in habitCard(habit) }
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("元气小事")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.cocoa)
            Spacer()
            Button {
                showingDatePicker = true
            } label: {
                Image(systemName: "calendar")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.78), in: Circle())
            }
            .accessibilityLabel("选择记录日期")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
    }

    private var weekStrip: some View {
        HStack(spacing: 2) {
            Button { moveSelectedDate(byWeeks: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 54)
                    .contentShape(Rectangle())
            }

            ForEach(weekDates, id: \.self) { date in
                dateChip(date)
            }

            Button { moveSelectedDate(byWeeks: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 54)
                    .contentShape(Rectangle())
            }
            .disabled(isToday)
            .opacity(isToday ? 0.3 : 1)
        }
        .frame(maxWidth: .infinity)
    }

    private func dateChip(_ date: Date) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let future = date > today
        let day = Calendar.current.component(.day, from: date)
        let weekday = date.formatted(.dateTime.weekday(.abbreviated))

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text(weekday)
                    .font(.caption2)
                Text("\(day)")
                    .font(.body.weight(.semibold))
                Text(selected ? (isToday ? String(localized: "今天") : String(localized: "回顾")) : " ")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(selected ? .white : (future ? Color.secondary.opacity(0.45) : AppTheme.cocoa))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(selected ? AppTheme.rose : .clear, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(future)
        .accessibilityLabel(date.formatted(date: .long, time: .omitted))
    }

    private var backfillBanner: some View {
        Label("正在回顾 \(selectedDate.formatted(.dateTime.month().day()))", systemImage: "clock.arrow.circlepath")
            .font(.caption.weight(.medium))
            .foregroundStyle(AppTheme.rose)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(AppTheme.blush.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.rose.opacity(0.2)))
    }

    private func habitCard(_ habit: EnergyHabit) -> some View {
        let checked = store.isCompleted(habit, on: selectedDate)
        return Button {
            let didComplete = store.toggle(habit, on: selectedDate)
            playCheckInHaptic(completed: didComplete)
            if didComplete {
                showCelebration(for: habit.id, isFirstWin: completed == 1)
            } else if celebratingHabitID == habit.id {
                celebratingHabitID = nil
                firstWinCelebrating = false
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: habit.symbol)
                        .symbolRenderingMode(.monochrome)
                        .font(.title3)
                        .foregroundStyle(Color(hex: habit.colorHex))
                        .frame(width: 40, height: 40)
                        .background(Color(hex: habit.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                    Spacer()
                    Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(checked ? AppTheme.rose : AppTheme.rose.opacity(0.45))
                        .overlay {
                            if celebratingHabitID == habit.id {
                                Circle()
                                    .stroke(AppTheme.rose.opacity(0.35), lineWidth: 3)
                                    .frame(width: 50, height: 50)
                                    .transition(.opacity)
                            }
                        }
                }

                Text(habit.localizedName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.cocoa)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
                if checked {
                    Text("+1 元气")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.rose)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Color.clear.frame(height: 15)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(checked ? AppTheme.blush.opacity(0.88) : .white.opacity(0.8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.rose.opacity(checked ? 0.28 : 0.1)))
            .overlay(alignment: .bottom) {
                if celebratingHabitID == habit.id {
                    celebrationBubble
                        .padding(.horizontal, 7)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .shadow(color: AppTheme.rose.opacity(checked ? 0.1 : 0.05), radius: 9, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!store.isReady)
        .opacity(store.isReady ? 1 : 0.62)
        .zIndex(celebratingHabitID == habit.id ? 10 : 0)
        .accessibilityLabel(
            String(
                format: NSLocalizedString("%@，%@", comment: "Habit completion accessibility label"),
                habit.localizedName,
                NSLocalizedString(checked ? "已记录" : "还未记录", comment: "Completion state")
            )
        )
    }

    private var celebrationBubble: some View {
        HStack(spacing: 3) {
            Text("🌹 完成一件小事")
                .foregroundStyle(AppTheme.cocoa)
            Text("元气+1")
                .foregroundStyle(AppTheme.rose)
        }
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.96), in: Capsule())
        .overlay(Capsule().stroke(AppTheme.rose.opacity(0.22)))
        .shadow(color: AppTheme.rose.opacity(0.18), radius: 10, y: 5)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                if completed == 0 {
                    GentleEmptyState(
                        symbol: isToday ? "heart" : "moon.stars",
                        title: isToday ? "今天也可以慢慢来" : "这一天安安静静的",
                        message: isToday ? "一件也值得庆祝，想记录时再开始" : "没有记录也没关系，生活仍在轻轻发生",
                        compact: true
                    )
                } else {
                    Label {
                        if isToday { Text("今日小胜利  \(completed)") }
                        else { Text("这天的小胜利  \(completed)") }
                    } icon: {
                        Image(systemName: "trophy.fill")
                    }
                    .foregroundStyle(AppTheme.cocoa)
                }
                Spacer()
                if completed > 0 {
                    Text("能量 +\(completed) ⚡️").foregroundStyle(AppTheme.rose)
                }
            }
            if completed > 0 {
                Divider().overlay(AppTheme.rose.opacity(0.12))
                Text(encouragementText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.rose)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.headline)
        .padding(18)
        .background(AppTheme.blush.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
    }

    private var energyTitle: String {
        if isToday { return String(localized: "今日元气  \(completed)") }
        return String(localized: "\(selectedDate.formatted(.dateTime.month().day()))元气  \(completed)")
    }

    private var weekDates: [Date] {
        let weekday = Calendar.current.component(.weekday, from: selectedDate)
        let daysAfterMonday = (weekday + 5) % 7
        guard let monday = Calendar.current.date(byAdding: .day, value: -daysAfterMonday, to: selectedDate) else { return [] }
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: monday) }
    }

    private func moveSelectedDate(byWeeks weeks: Int) {
        guard let candidate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: selectedDate) else { return }
        selectedDate = min(candidate, today)
    }

    private func watchForNewDay() async {
        while !Task.isCancelled {
            let now = Date.now
            let nextDay = Calendar.current.nextDate(
                after: now,
                matching: DateComponents(hour: 0, minute: 0, second: 1),
                matchingPolicy: .nextTime
            ) ?? now.addingTimeInterval(60)
            try? await Task.sleep(for: .seconds(max(1, nextDay.timeIntervalSince(now))))
            guard !Task.isCancelled else { return }
            refreshToday()
        }
    }

    private func refreshToday() {
        let previousToday = today
        let newToday = Calendar.current.startOfDay(for: .now)
        guard newToday != previousToday else { return }
        today = newToday
        if Calendar.current.isDate(selectedDate, inSameDayAs: previousToday) {
            selectedDate = newToday
        }
        store.syncCloudNow()
    }

    private var encouragementText: String {
        switch completed {
        case 0: String(localized: "今天慢一点也没关系")
        case 1: String(localized: "一个小小的开始，已经很棒")
        case 2...3: String(localized: "今天正在慢慢亮起来")
        default: String(localized: "收集到了好多生活里的光")
        }
    }

    private func showCelebration(for habitID: UUID, isFirstWin: Bool) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
            celebratingHabitID = habitID
            firstWinCelebrating = isFirstWin
        }
        Task {
            try? await Task.sleep(for: .seconds(1.25))
            guard celebratingHabitID == habitID else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                celebratingHabitID = nil
                firstWinCelebrating = false
            }
        }
    }

    private func playCheckInHaptic(completed: Bool) {
        guard hapticsEnabled else { return }
        if completed {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        } else {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.7)
        }
    }
}

private struct FirstWinCelebration: View {
    var body: some View {
        ZStack {
            Circle().fill(AppTheme.gold.opacity(0.2)).frame(width: 150, height: 150).blur(radius: 14)
            ForEach(0..<10, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "heart.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 16 : 8, weight: .semibold))
                    .foregroundStyle(index.isMultiple(of: 2) ? AppTheme.gold : AppTheme.rose.opacity(0.75))
                    .offset(y: -74)
                    .rotationEffect(.degrees(Double(index) * 36))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CheckInDatePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var selection: Date
    @State private var draft: Date
    let latestDate: Date

    init(selection: Binding<Date>, latestDate: Date) {
        _selection = selection
        _draft = State(initialValue: selection.wrappedValue)
        self.latestDate = latestDate
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker(
                    "选择记录日期",
                    selection: $draft,
                    in: ...latestDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(AppTheme.rose)
                .padding(16)
                .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22))

                Text("可以回顾和记录过去的元气小事，未来日期暂不可选择")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(18)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("选择记录日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        selection = Calendar.current.startOfDay(for: draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
