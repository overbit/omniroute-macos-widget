import XCTest
@testable import OmniRouteCore

final class OmniRouteCoreTests: XCTestCase {
    func testNormalizesOpenAIBaseURLToServerRoot() throws {
        let url = try OmniRouteClient.normalizedServerURL("http://localhost:20128/v1/")
        XCTAssertEqual(url.absoluteString, "http://localhost:20128")
    }

    func testPreservesReverseProxyPrefix() throws {
        let url = try OmniRouteClient.normalizedServerURL("https://example.com/omniroute/v1")
        XCTAssertEqual(url.absoluteString, "https://example.com/omniroute")
    }

    func testDecodesPersonalAndProviderUsage() throws {
        let json = """
        {
          "allowed": true,
          "personal": {
            "dailySpentUsd": 1.25,
            "dailyLimitUsd": 5,
            "weeklySpentUsd": 8,
            "weeklyLimitUsd": 20
          },
          "provider": {
            "connectionId": "conn-claude",
            "provider": "claude",
            "plan": "Claude Max",
            "quotas": {
              "weekly": {
                "used": 25,
                "total": 100,
                "remaining": 75,
                "resetAt": "2026-10-01T03:00:00.000Z"
              }
            }
          },
          "providers": [
            {
              "connectionId": "conn-claude",
              "provider": "claude",
              "plan": "Claude Max",
              "quotas": {
                "weekly": {
                  "used": 25,
                  "total": 100,
                  "remaining": 75
                }
              }
            },
            {
              "connectionId": "conn-codex",
              "provider": "codex",
              "plan": "Codex Pro",
              "quotas": {
                "weekly": {
                  "usedPercentage": 9
                }
              }
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(UsageResponse.self, from: Data(json.utf8))

        XCTAssertTrue(response.allowed)
        XCTAssertEqual(response.personal?.dailySpentUsd, 1.25)
        XCTAssertEqual(response.personal?.dailyUsedFraction, 0.25)
        XCTAssertEqual(response.allProviders.count, 2)
        XCTAssertEqual(response.allProviders[0].quotas["weekly"]?.remainingPercent, 75)
        XCTAssertEqual(response.allProviders[1].quotas["weekly"]?.remainingPercent, 91)
    }

    func testFallsBackToSelectedProviderForOlderServers() throws {
        let json = """
        {
          "allowed": true,
          "personal": null,
          "provider": {
            "connectionId": "conn-claude",
            "provider": "claude",
            "plan": null,
            "quotas": {}
          }
        }
        """

        let response = try JSONDecoder().decode(UsageResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.allProviders.map(\.provider), ["claude"])
    }
}
