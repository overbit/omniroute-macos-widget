import SwiftUI

@main
struct OmniRouteWidgetApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        WindowGroup("OmniRoute Widget") {
            SettingsView(store: store)
                .task {
                    if store.isConfigured {
                        await store.refresh()
                    }
                }
                .onOpenURL { _ in
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentSize)
    }
}
