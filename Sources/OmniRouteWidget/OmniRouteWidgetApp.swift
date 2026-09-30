import SwiftUI

@main
struct OmniRouteWidgetApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            UsageMenuView(store: store)
                .task {
                    if store.isConfigured { await store.refresh() }
                }
        } label: {
            Label("OmniRoute", systemImage: "point.3.connected.trianglepath.dotted")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
        }
    }
}
