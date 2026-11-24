import SwiftUI

struct RootView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { TodayView() }
                .tabItem { Label("今日", systemImage: "sun.max") }
                .tag(0)

            NavigationStack { EnergyCalendarView() }
                .tabItem { Label("日历", systemImage: "calendar") }
                .tag(1)

            HabitListView()
                .tabItem { Label("小事", systemImage: "sparkles") }
                .tag(2)

            NavigationStack { SettingsView() }
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(3)
        }
    }
}
