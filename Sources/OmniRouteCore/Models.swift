import Foundation

public struct UsageResponse: Decodable, Sendable {
    public let allowed: Bool
    public let personal: PersonalUsage?
    public let provider: ProviderUsage?
    public let providers: [ProviderUsage]?
    public let error: APIErrorPayload?

    public var allProviders: [ProviderUsage] {
        if let providers, !providers.isEmpty {
            return providers
        }
        return provider.map { [$0] } ?? []
    }
}

public struct APIErrorPayload: Decodable, Sendable {
    public let message: String?
}

public struct PersonalUsage: Decodable, Sendable {
    public let enabled: Bool?
    public let dailyLimitUsd: Double?
    public let weeklyLimitUsd: Double?
    public let dailySpentUsd: Double?
    public let weeklySpentUsd: Double?
    public let dailyWindowStartIso: String?
    public let dailyResetAtIso: String?
    public let weeklyWindowStartIso: String?
    public let weeklyResetAtIso: String?
    public let dailyExceeded: Bool?
    public let weeklyExceeded: Bool?

    public var dailyUsedFraction: Double? {
        fraction(spent: dailySpentUsd, limit: dailyLimitUsd)
    }

    public var weeklyUsedFraction: Double? {
        fraction(spent: weeklySpentUsd, limit: weeklyLimitUsd)
    }

    private func fraction(spent: Double?, limit: Double?) -> Double? {
        guard let spent, let limit, limit > 0 else { return nil }
        return min(max(spent / limit, 0), 1)
    }
}

public struct ProviderUsage: Decodable, Sendable, Identifiable {
    public let connectionId: String
    public let provider: String
    public let plan: String?
    public let quotas: [String: ProviderQuota]

    public var id: String { connectionId }

    enum CodingKeys: String, CodingKey {
        case connectionId
        case provider
        case plan
        case quotas
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        connectionId = try container.decode(String.self, forKey: .connectionId)
        provider = try container.decode(String.self, forKey: .provider)
        quotas = (try? container.decode([String: ProviderQuota].self, forKey: .quotas)) ?? [:]

        if let value = try? container.decode(String.self, forKey: .plan) {
            plan = value
        } else if let value = try? container.decode(Double.self, forKey: .plan) {
            plan = value.formatted()
        } else {
            plan = nil
        }
    }
}

public struct ProviderQuota: Decodable, Sendable {
    public let used: Double?
    public let total: Double?
    public let remaining: Double?
    public let usedPercentage: Double?
    public let remainingPercentage: Double?
    public let resetAt: String?

    public var remainingPercent: Double? {
        if let remainingPercentage {
            return clamp(remainingPercentage)
        }
        if let usedPercentage {
            return clamp(100 - usedPercentage)
        }
        if let used, let total, total > 0 {
            return clamp(100 - (used / total * 100))
        }
        if let remaining, remaining >= 0, remaining <= 100 {
            return clamp(remaining)
        }
        if let used, used >= 0, used <= 100 {
            return clamp(100 - used)
        }
        return nil
    }

    public var remainingFraction: Double? {
        remainingPercent.map { $0 / 100 }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}
