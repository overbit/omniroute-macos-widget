import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class UsageStore: ObservableObject {
    @Published var usage: UsageResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published private(set) var baseURL: String

    private var apiKey: String

    init() {
        self.baseURL = OmniRouteSharedConfiguration.loadBaseURL()
        self.apiKey = OmniRouteSharedConfiguration.loadAPIKey()
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func currentAPIKey() -> String {
        apiKey
    }

    func saveConfiguration(baseURL: String, apiKey: String) throws {
        let normalizedURL = try OmniRouteClient.normalizedServerURL(baseURL).absoluteString
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw OmniRouteClientError.missingAPIKey
        }

        try OmniRouteSharedConfiguration.saveAPIKey(trimmedKey)
        OmniRouteSharedConfiguration.saveBaseURL(normalizedURL)

        self.baseURL = normalizedURL
        self.apiKey = trimmedKey
        WidgetCenter.shared.reloadAllTimelines()
    }

    func refresh() async {
        guard isConfigured else {
            usage = nil
            errorMessage = "Configure your OmniRoute URL and API key."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = try OmniRouteClient(baseURL: baseURL, apiKey: apiKey)
            usage = try await client.fetchUsage()
            lastUpdated = Date()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
