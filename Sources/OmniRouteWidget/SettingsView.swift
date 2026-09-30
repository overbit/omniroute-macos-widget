import SwiftUI
import WidgetKit

struct SettingsView: View {
    @ObservedObject var store: UsageStore

    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var saveError: String?
    @State private var saveConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("OmniRoute URL") {
                        TextField("http://localhost:20128", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                    }

                    LabeledContent("API key") {
                        SecureField("API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                    }

                    Text("The API key is stored in Keychain and shared with the WidgetKit extension. Usage Command must be enabled for this key.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(4)
            }

            if let saveError {
                Label(saveError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let usage = store.usage {
                connectionSummary(usage)
            } else if store.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking OmniRoute…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Text("After saving, add “OmniRoute” from the macOS widget gallery.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Refresh Widget") {
                    WidgetCenter.shared.reloadAllTimelines()
                }

                Button("Save & Test") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560)
        .onAppear {
            baseURL = store.baseURL
            apiKey = store.currentAPIKey()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(store.errorMessage == nil && store.isConfigured ? Color.green : Color.secondary)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text("OmniRoute")
                    .font(.headline)
                Text("Desktop Widget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if saveConfirmation {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func connectionSummary(_ usage: UsageResponse) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text("\(usage.allProviders.count) provider\(usage.allProviders.count == 1 ? "" : "s") available")
                .font(.caption)

            if let lastUpdated = store.lastUpdated {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("checked \(lastUpdated, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func save() {
        saveError = nil
        saveConfirmation = false

        do {
            try store.saveConfiguration(baseURL: baseURL, apiKey: apiKey)
            baseURL = store.baseURL
            saveConfirmation = true
            Task { await store.refresh() }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
