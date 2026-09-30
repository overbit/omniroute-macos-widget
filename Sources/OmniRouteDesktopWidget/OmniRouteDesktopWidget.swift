import SwiftUI
import WidgetKit

struct UsageEntry: TimelineEntry {
    enum State {
        case configured(UsageResponse)
        case notConfigured
        case failed(String)
    }

    let date: Date
    let state: State
}

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: .now, state: .configured(Self.sampleUsage))
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }

        Task {
            completion(await loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now)
                ?? .now.addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    private func loadEntry() async -> UsageEntry {
        let baseURL = OmniRouteSharedConfiguration.loadBaseURL()
        let apiKey = OmniRouteSharedConfiguration.loadAPIKey()

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return UsageEntry(date: .now, state: .notConfigured)
        }

        do {
            let client = try OmniRouteClient(baseURL: baseURL, apiKey: apiKey)
            let usage = try await client.fetchUsage()
            return UsageEntry(date: .now, state: .configured(usage))
        } catch {
            return UsageEntry(date: .now, state: .failed(error.localizedDescription))
        }
    }

    private static let sampleUsage = UsageResponse(
        allowed: true,
        personal: PersonalUsage(
            dailyLimitUsd: 10,
            weeklyLimitUsd: 50,
            dailySpentUsd: 2.1,
            weeklySpentUsd: 18.4
        ),
        providers: [
            ProviderUsage(
                connectionId: "openai",
                provider: "openai",
                plan: "Pro",
                quotas: [
                    "session": ProviderQuota(remainingPercentage: 73, resetAt: "2026-10-01T18:30:00Z"),
                    "weekly": ProviderQuota(remainingPercentage: 48, resetAt: "2026-10-03T12:00:00Z")
                ]
            ),
            ProviderUsage(
                connectionId: "claude",
                provider: "claude",
                plan: "Max",
                quotas: [
                    "session": ProviderQuota(remainingPercentage: 100, resetAt: "2026-10-01T20:00:00Z"),
                    "weekly": ProviderQuota(remainingPercentage: 82, resetAt: "2026-10-05T12:00:00Z")
                ]
            ),
            ProviderUsage(
                connectionId: "codex",
                provider: "codex",
                plan: "Team",
                quotas: [
                    "5h": ProviderQuota(remainingPercentage: 36, resetAt: "2026-10-01T16:00:00Z"),
                    "weekly": ProviderQuota(remainingPercentage: 15, resetAt: "2026-10-06T12:00:00Z")
                ]
            )
        ]
    )
}

struct OmniRouteDesktopWidget: Widget {
    static let kind = "OmniRouteDesktopWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: UsageTimelineProvider()) { entry in
            OmniRouteWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "omniroute-widget://settings"))
        }
        .configurationDisplayName("OmniRoute")
        .description("Compact OmniRoute provider quota and API-key usage.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct OmniRouteWidgets: WidgetBundle {
    var body: some Widget {
        OmniRouteDesktopWidget()
    }
}

private struct OmniRouteWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: UsageEntry

    var body: some View {
        switch entry.state {
        case .configured(let usage):
            UsageDashboard(usage: usage, updatedAt: entry.date, family: family)
        case .notConfigured:
            WidgetMessage(
                symbol: "key",
                title: "Configure OmniRoute",
                message: "Open the OmniRoute app and add the server URL and API key."
            )
        case .failed(let message):
            WidgetMessage(
                symbol: "exclamationmark.triangle.fill",
                title: "OmniRoute unavailable",
                message: message
            )
        }
    }
}

private struct UsageDashboard: View {
    let usage: UsageResponse
    let updatedAt: Date
    let family: WidgetFamily

    private var visibleProviders: [ProviderUsage] {
        Array(usage.allProviders.prefix(providerLimit))
    }

    private var providerLimit: Int {
        switch family {
        case .systemSmall: 1
        case .systemMedium: 3
        default: 7
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 9) {
            header

            Divider()

            HStack {
                Text("USAGE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("% left")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            if visibleProviders.isEmpty {
                Text("No cached provider quota data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 8) {
                    ForEach(visibleProviders) { provider in
                        ProviderRow(provider: provider, compact: family == .systemSmall)
                    }
                }
            }

            Spacer(minLength: 0)

            if family != .systemSmall {
                footer
            }
        }
        .padding(family == .systemSmall ? 12 : 14)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)

                Text("OmniRoute")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button(intent: RefreshUsageIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 4) {
                Text("\(usage.allProviders.count) provider\(usage.allProviders.count == 1 ? "" : "s")")
                Text("·")
                Text("updated \(updatedAt, style: .relative)")
            }
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let personal = usage.personal,
           let spent = personal.weeklySpentUsd {
            HStack {
                Text("API key this week")
                    .foregroundStyle(.secondary)

                Spacer()

                if let limit = personal.weeklyLimitUsd {
                    Text("\(spent.formatted(.currency(code: "USD"))) / \(limit.formatted(.currency(code: "USD")))")
                        .monospacedDigit()
                } else {
                    Text(spent.formatted(.currency(code: "USD")))
                        .monospacedDigit()
                }
            }
            .font(.system(size: 9.5, weight: .medium))
        }
    }
}

private struct ProviderRow: View {
    let provider: ProviderUsage
    let compact: Bool

    private var quotas: [(String, ProviderQuota)] {
        Array(
            provider.quotas
                .sorted { quotaRank($0.key) < quotaRank($1.key) }
                .prefix(compact ? 1 : 2)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ProviderBadge(provider: provider.provider)

                Text(provider.provider.capitalized)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)

                if let plan = provider.plan, !plan.isEmpty, !compact {
                    Text(plan)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()
            }

            if quotas.isEmpty {
                Text("No cached quota")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(quotas, id: \.0) { name, quota in
                    QuotaLine(name: name, quota: quota)
                }
            }
        }
    }

    private func quotaRank(_ value: String) -> Int {
        let normalized = value.lowercased()
        if normalized.contains("session") || normalized.contains("5h") { return 0 }
        if normalized.contains("daily") || normalized.contains("1d") { return 1 }
        if normalized.contains("weekly") || normalized.contains("7d") { return 2 }
        if normalized.contains("monthly") || normalized.contains("30d") { return 3 }
        return 4
    }
}

private struct ProviderBadge: View {
    let provider: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(width: 16, height: 16)

            Text(String(provider.prefix(1)).uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct QuotaLine: View {
    let name: String
    let quota: ProviderQuota

    private var remaining: Double {
        quota.remainingPercent ?? 0
    }

    private var statusColor: Color {
        if remaining < 20 { return .red }
        if remaining < 50 { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(shortLabel(name))
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)

                    Capsule()
                        .fill(statusColor)
                        .frame(width: geometry.size.width * max(0, min(remaining / 100, 1)))
                }
            }
            .frame(height: 6)

            Text("\(Int(remaining.rounded()))%")
                .font(.system(size: 9.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(statusColor)
                .frame(width: 31, alignment: .trailing)

            if let reset = resetDate(quota.resetAt) {
                Text(reset, style: .relative)
                    .font(.system(size: 8.5))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .frame(width: 38, alignment: .trailing)
                    .lineLimit(1)
            }
        }
        .frame(height: 11)
    }

    private func shortLabel(_ value: String) -> String {
        let normalized = value.lowercased()
        if normalized.contains("session") { return "sess" }
        if normalized.contains("5h") { return "5h" }
        if normalized.contains("daily") || normalized.contains("1d") { return "1d" }
        if normalized.contains("weekly") || normalized.contains("7d") { return "wk" }
        if normalized.contains("monthly") || normalized.contains("30d") { return "mo" }
        return String(value.prefix(4)).lowercased()
    }

    private func resetDate(_ value: String?) -> Date? {
        guard let value else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

private struct WidgetMessage: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Text("Open OmniRoute to configure")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
    }
}
