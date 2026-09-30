import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("OmniRoute")
                        .font(.headline)
                    Text("Desktop Widget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Add OmniRoute from the macOS widget gallery.", systemImage: "plus.square.on.square")
                    Label("Right-click the widget and choose Edit Widget.", systemImage: "slider.horizontal.3")
                    Label("Enter the OmniRoute URL and API key there.", systemImage: "key")
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            Text("The desktop widget connects directly to OmniRoute. Its URL and API key are stored by macOS as part of that widget's configuration, so this build does not require App Group or shared-Keychain entitlements.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("The API key must have Usage Command enabled in OmniRoute.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 520)
    }
}
