import SwiftUI

@main
struct YuanQiThingsApp: App {
    @StateObject private var store = EnergyStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasPresentedInitialUI = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(AppTheme.rose)
                .task {
                    hasPresentedInitialUI = true
                    store.start()
                }
                .onChange(of: scenePhase) {
                    guard hasPresentedInitialUI else { return }
                    if scenePhase == .background {
                        store.syncWidgetNow()
                        store.syncCloudNow()
                    } else if scenePhase == .active {
                        store.reloadFromSharedStorage()
                    }
                }
        }
    }
}
