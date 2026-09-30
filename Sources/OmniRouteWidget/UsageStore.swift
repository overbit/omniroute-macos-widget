import Foundation
import OmniRouteCore
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published var usage: UsageResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    @AppStorage("omnirouteBaseURL") var baseURL = "http://localhost:20128"
    private var apiKey = KeychainStore.loadAPIKey()

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func currentAPIKey() -> String { apiKey }

    func saveConfiguration(baseURL: String, apiKey: String) throws {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        try KeychainStore.saveAPIKey(trimmedKey)
        self.apiKey = trimmedKey
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
