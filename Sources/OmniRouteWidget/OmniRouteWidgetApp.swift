import SwiftUI

@main
struct OmniRouteWidgetApp: App {
    var body: some Scene {
        WindowGroup("OmniRoute Widget") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}
