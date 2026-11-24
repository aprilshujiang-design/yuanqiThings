import SwiftUI
import Charts

struct EnergyCalendarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: EnergyStore
    @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    @State private var selectedDate = Date.now

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)
    private var weekdays: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return Array(symbols.dropFirst()) + symbols.prefix(1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                titleHeader
                monthHeader
                calendarCard
                selectedDayReview
                summaryCard
                VStack(spacing: 5) {
                    Text("小小积累，正在让这个月闪闪发光 ✦")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.cocoa)
                    Text("休息不是中断，想回来时随时都可以")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var titleHeader: some View {
        ZStack {
            CalendarHeaderDecoration()

            HStack(spacing: 10) {
                Image("EnergySun")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 76, height: 76)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.gold.opacity(0.34), radius: 10)
                    .accessibilityHidden(true)

                Text("元气日历")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.cocoa)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 112)
        .accessibilityElement(children: .combine)
    }

    private var monthHeader: some View {
        HStack {
            monthButton("chevron.left", label: "上个月") { changeMonth(-1) }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .font(.title3.weight(.bold)).foregroundStyle(AppTheme.cocoa)
                .contentTransition(.numericText())
            Spacer()
            monthButton("chevron.right", label: "下个月") { changeMonth(1) }
        }
    }

    private func monthButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.headline.weight(.bold)).foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(LinearGradient(colors: [AppTheme.rose, AppTheme.coral], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                .shadow(color: AppTheme.rose.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }

    private var calendarCard: some View {
        SoftCard {
            VStack(spacing: 17) {
                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day).font(.caption.weight(.medium)).foregroundStyle(AppTheme.cocoa.opacity(0.76))
                    }
                    ForEach(Array(calendarCells.enumerated()), id: \.offset) { _, date in
                        if let date { dayCell(date) } else { Color.clear.frame(height: 43) }
                    }
                }
                Divider().overlay(AppTheme.rose.opacity(0.08))
                VStack(spacing: 9) {
                    Text("本月元气趋势").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.cocoa)
                    if monthlyTotal == 0 {
                        GentleEmptyState(
                            symbol: "sparkles",
                            title: "这个月还是一张柔软的白纸",
                            message: "不必追赶，想记录的那天自然会亮起来",
                            compact: true
                        )
                        .frame(height: 112)
                    } else {
                        energyChart
                        HStack(spacing: 8) {
                            Text("低")
                            ForEach(0..<5, id: \.self) { level in
                                Circle().fill(energyColor(level)).frame(width: 15, height: 15)
                            }
                            Text("高")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityElement(children: .ignore).accessibilityLabel("能量颜色由低到高")
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let count = store.completedCount(on: date)
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { selectedDate = date }
        } label: {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline.weight(selected ? .bold : .medium))
                .foregroundStyle(count >= 4 ? .white : AppTheme.cocoa)
                .frame(maxWidth: .infinity).frame(height: 43)
                .background(energyColor(min(count, 4)), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 13).stroke(selected ? AppTheme.rose : .clear, lineWidth: 2.5).padding(selected ? -2 : 0) }
                .overlay(alignment: .topTrailing) {
                    if selected { Image(systemName: "sparkle").font(.caption2.weight(.bold)).foregroundStyle(AppTheme.gold).offset(x: 3, y: -4) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(date.formatted(date: .long, time: .omitted))，记录 \(count) 件")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var energyChart: some View {
        Chart(points) { point in
            AreaMark(x: .value("日期", point.day), y: .value("元气", point.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(colors: [AppTheme.rose.opacity(0.3), AppTheme.rose.opacity(0.015)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("日期", point.day), y: .value("元气", point.value))
                .interpolationMethod(.catmullRom).foregroundStyle(AppTheme.rose)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            if point.value > 0 {
                PointMark(x: .value("日期", point.day), y: .value("元气", point.value))
                    .foregroundStyle(point.selected ? AppTheme.gold : AppTheme.rose)
                    .symbolSize(point.selected ? 72 : 25)
            }
        }
        .chartYScale(domain: 0...chartMaximum).chartXAxis(.hidden).chartYAxis(.hidden)
        .frame(height: 92).accessibilityLabel("本月每日元气变化曲线")
    }

    private var summaryCard: some View {
        SoftCard {
            HStack(spacing: 0) {
                metric("本月元气", value: "\(monthlyTotal)", symbol: "sun.max.fill")
                metricDivider
                metric("本月有元气的日子", value: String(localized: "\(activeDayCount)天"), symbol: "calendar.badge.checkmark")
                metricDivider
                metric("闪光一天", value: bestDay, symbol: "sparkles")
            }
        }
    }

    private func metric(_ title: LocalizedStringKey, value: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title3).foregroundStyle(symbol == "sparkles" ? AppTheme.gold : AppTheme.rose)
            Text(title).font(.caption).foregroundStyle(AppTheme.cocoa)
            Text(value).font(.system(size: value.count > 4 ? 18 : 25, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.rose).lineLimit(1).minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }

    private var metricDivider: some View {
        Rectangle().fill(AppTheme.rose.opacity(0.12)).frame(width: 1, height: 70)
    }

    private var selectedDayReview: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedDate.formatted(.dateTime.month().day().weekday(.wide)))
                            .font(.headline).foregroundStyle(AppTheme.cocoa)
                        Text("这一天的元气小事")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !selectedHabits.isEmpty {
                        Text("\(selectedHabits.count) 次小胜利")
                            .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.rose)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(AppTheme.blush, in: Capsule())
                    }
                }

                if selectedHabits.isEmpty {
                    GentleEmptyState(
                        symbol: "moon.stars",
                        title: "这一天安安静静的",
                        message: "没有记录也没关系，回望本身就是一种温柔",
                        compact: true
                    )
                    .padding(.vertical, 5)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(selectedHabits) { habit in
                            HStack(spacing: 7) {
                                Image(systemName: habit.symbol)
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(Color(hex: habit.colorHex))
                                    .frame(width: 25, height: 25)
                                    .background(Color(hex: habit.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: 7))
                                Text(habit.localizedName)
                                    .font(.caption.weight(.medium)).foregroundStyle(AppTheme.cocoa)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(.white.opacity(0.72), in: Capsule())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct Point: Identifiable {
        let day: Int, value: Int
        let selected: Bool
        var id: Int { day }
    }

    private var monthStart: Date? { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: displayedMonth)) }
    private var points: [Point] {
        guard let start = monthStart, let range = Calendar.current.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let selectedDay = Calendar.current.isDate(selectedDate, equalTo: displayedMonth, toGranularity: .month) ? Calendar.current.component(.day, from: selectedDate) : -1
        return range.compactMap { day in
            guard let date = Calendar.current.date(byAdding: .day, value: day - 1, to: start) else { return nil }
            return Point(day: day, value: store.completedCount(on: date), selected: day == selectedDay)
        }
    }
    private var monthlyTotal: Int { points.reduce(0) { $0 + $1.value } }
    private var activeDayCount: Int { points.filter { $0.value > 0 }.count }
    private var selectedHabits: [EnergyHabit] { store.habits.filter { store.isCompleted($0, on: selectedDate) } }
    private var chartMaximum: Int { max(4, (points.map(\.value).max() ?? 0) + 1) }
    private var bestDay: String {
        guard let best = points.max(by: { $0.value < $1.value }), best.value > 0 else { return String(localized: "等你发现") }
        let month = Calendar.current.component(.month, from: displayedMonth)
        return String(localized: "\(month)月\(best.day)日")
    }
    private var calendarCells: [Date?] {
        guard let start = monthStart, let range = Calendar.current.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let offset = (Calendar.current.component(.weekday, from: start) + 5) % 7
        return Array(repeating: nil, count: offset) + range.compactMap { Calendar.current.date(byAdding: .day, value: $0 - 1, to: start) }.map(Optional.some)
    }
    private func energyColor(_ level: Int) -> Color {
        ["FFFAF7", "FFDADB", "FFB7BE", "FF8D9C", "F45F7A"].map(Color.init(hex:))[max(0, min(level, 4))]
    }
    private func changeMonth(_ value: Int) {
        guard let month = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
            displayedMonth = month
            selectedDate = Calendar.current.isDate(month, equalTo: .now, toGranularity: .month) ? .now : month
        }
    }
}

private struct CalendarHeaderDecoration: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HeaderCurve()
                    .stroke(Color.white.opacity(0.86), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                    .frame(width: proxy.size.width * 0.34, height: 54)
                    .position(x: proxy.size.width * 0.86, y: 57)

                sparkle(size: 19, color: AppTheme.gold)
                    .position(x: 13, y: 73)
                sparkle(size: 10, color: AppTheme.gold)
                    .position(x: 48, y: 65)
                sparkle(size: 13, color: AppTheme.gold)
                    .position(x: proxy.size.width * 0.72, y: 24)
                sparkle(size: 9, color: .white)
                    .position(x: proxy.size.width * 0.78, y: 19)
                sparkle(size: 15, color: AppTheme.gold)
                    .position(x: proxy.size.width - 23, y: 70)
                sparkle(size: 11, color: .white)
                    .position(x: proxy.size.width - 7, y: 29)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func sparkle(size: CGFloat, color: Color) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
    }
}

private struct HeaderCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.72))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 5),
            control1: CGPoint(x: rect.width * 0.25, y: rect.maxY * 0.08),
            control2: CGPoint(x: rect.width * 0.62, y: rect.maxY * 0.95)
        )
        path.move(to: CGPoint(x: rect.width * 0.23, y: rect.height * 0.56))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.38, y: rect.height * 0.72),
            control1: CGPoint(x: rect.width * 0.34, y: rect.height * 0.42),
            control2: CGPoint(x: rect.width * 0.46, y: rect.height * 0.57)
        )
        return path
    }
}
