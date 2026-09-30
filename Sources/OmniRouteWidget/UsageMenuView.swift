import AppKit
import OmniRouteCore
import SwiftUI

struct UsageMenuView: View {
    @ObservedObject var store: UsageStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !store.isConfigured {
                EmptyStateView(title: "Connect OmniRoute", message: "Add the server URL and an API key with Usage Command enabled.")
            } else if let errorMessage = store.errorMessage, store.usage == nil {
                EmptyStateView(title: "Unable to load usage", message: errorMessage)
            } else if let usage = store.usage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let personal = usage.personal { PersonalUsageView(usage: personal) }
                        if usage.allProviders.isEmpty {
                            EmptyStateView(title: "No provider quota data", message: "OmniRoute has not cached provider quota data for this API key yet.")
                        } else {
                            ForEach(usage.allProviders) { provider in
                                ProviderUsageView(provider: provider)
                            }
                        }
                    }
                }
                .frame(maxHeight: 420)
            } else {
                ProgressView("Loading OmniRoute usage…")
                    .frame(maxWidth: .infinity, minHeight: 120)
            }

            if let errorMessage = store.errorMessage, store.usage != nil {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button("Settings…") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                if let lastUpdated = store.lastUpdated {
                    Text("Updated \(lastUpdated, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .disabled(store.isLoading)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("OmniRoute").font(.headline)
                Text(store.baseURL).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if store.isLoading { ProgressView().controlSize(.small) }
        }
    }
}

private struct PersonalUsageView: View {
    let usage: PersonalUsage

    var body: some View {
        GroupBox("API key spend") {
            VStack(spacing: 10) {
                spendRow(label: "Today", spent: usage.dailySpentUsd, limit: usage.dailyLimitUsd, fraction: usage.dailyUsedFraction)
                spendRow(label: "This week", spent: usage.weeklySpentUsd, limit: usage.weeklyLimitUsd, fraction: usage.weeklyUsedFraction)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func spendRow(label: String, spent: Double?, limit: Double?, fraction: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                Spacer()
                Text(spendText(spent: spent, limit: limit)).monospacedDigit().foregroundStyle(.secondary)
            }
            if let fraction { ProgressView(value: fraction) }
        }
    }

    private func spendText(spent: Double?, limit: Double?) -> String {
        guard let spent else { return "Unavailable" }
        let spentText = spent.formatted(.currency(code: "USD"))
        guard let limit else { return spentText }
        return "\(spentText) / \(limit.formatted(.currency(code: "USD")))"
    }
}

private struct ProviderUsageView: View {
    let provider: ProviderUsage

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(provider.provider.capitalized).font(.headline)
                    Spacer()
                    if let plan = provider.plan, !plan.isEmpty {
                        Text(plan).font(.caption).foregroundStyle(.secondary)
                    }
                }

                ForEach(sortedQuotas, id: \.key) { item in
                    quotaRow(name: item.key, quota: item.value)
                }
            }
            .padding(.top, 2)
        }
    }

    private var sortedQuotas: [(key: String, value: ProviderQuota)] {
        provider.quotas.sorted { quotaRank($0.key) < quotaRank($1.key) }
    }

    @ViewBuilder
    private func quotaRow(name: String, quota: ProviderQuota) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(displayName(name))
                Spacer()
                if let remaining = quota.remainingPercent {
                    Text("\(Int(remaining.rounded()))% left").monospacedDigit().foregroundStyle(.secondary)
                } else {
                    Text("Unavailable").foregroundStyle(.secondary)
                }
            }
            if let fraction = quota.remainingFraction { ProgressView(value: fraction) }
            if let resetAt = quota.resetAt, let date = ISO8601DateFormatter().date(from: resetAt) {
                Text("Resets \(date, style: .relative)").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func quotaRank(_ value: String) -> Int {
        let normalized = value.lowercased()
        if normalized.contains("session") || normalized.contains("5h") { return 0 }
        if normalized.contains("weekly") || normalized.contains("7d") { return 1 }
        if normalized.contains("monthly") || normalized.contains("30d") { return 2 }
        return 3
    }

    private func displayName(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ").capitalized
    }
}

private struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.33percent").font(.largeTitle).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .padding(.horizontal, 16)
    }
}
