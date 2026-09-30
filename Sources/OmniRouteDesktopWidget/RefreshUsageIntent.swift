import AppIntents
import WidgetKit

struct RefreshUsageIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh OmniRoute usage"
    static let description = IntentDescription("Reload OmniRoute usage in the desktop widget.")

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: OmniRouteDesktopWidget.kind)
        }
        return .result()
    }
}
