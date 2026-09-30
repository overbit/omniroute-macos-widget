import OmniRouteCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var saveError: String?
    @State private var saveConfirmation = false

    var body: some View {
        Form {
            Section("Connection") {
                TextField("OmniRoute URL", text: $baseURL, prompt: Text("http://localhost:20128"))
                    .textFieldStyle(.roundedBorder)
                SecureField("API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("The API key is stored in macOS Keychain. It must have Usage Command enabled in OmniRoute.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let saveError {
                Text(saveError).foregroundStyle(.red).font(.caption)
            }

            HStack {
                if saveConfirmation {
                    Label("Saved", systemImage: "checkmark.circle").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Save & Refresh") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 480)
        .onAppear {
            baseURL = store.baseURL
            apiKey = store.currentAPIKey()
        }
    }

    private func save() {
        saveError = nil
        saveConfirmation = false
        do {
            _ = try OmniRouteClient.normalizedServerURL(baseURL)
            try store.saveConfiguration(baseURL: baseURL, apiKey: apiKey)
            saveConfirmation = true
            Task { await store.refresh() }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
