import Foundation
import OmniRouteCore
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published var usage: UsageResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published private(set) var baseURL: String

    private let defaults: UserDefaults
    private var apiKey: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.baseURL = defaults.string(forKey: "omnirouteBaseURL") ?? "http://localhost:20128"
        self.apiKey = KeychainStore.loadAPIKey()
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

        try KeychainStore.saveAPIKey(trimmedKey)
        defaults.set(normalizedURL, forKey: "omnirouteBaseURL")

        self.baseURL = normalizedURL
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
