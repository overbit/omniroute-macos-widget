import AppIntents
import WidgetKit

struct RefreshUsageIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh OmniRoute usage"
    static var description = IntentDescription("Reload OmniRoute usage in the desktop widget.")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: OmniRouteDesktopWidget.kind)
        return .result()
    }
}
