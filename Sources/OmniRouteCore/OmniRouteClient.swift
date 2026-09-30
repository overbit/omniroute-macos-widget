import Foundation

public struct OmniRouteClient: Sendable {
    private let serverURL: URL
    private let apiKey: String
    private let session: URLSession

    public init(baseURL: String, apiKey: String, session: URLSession = .shared) throws {
        self.serverURL = try Self.normalizedServerURL(baseURL)
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
    }

    public func fetchUsage() async throws -> UsageResponse {
        guard !apiKey.isEmpty else {
            throw OmniRouteClientError.missingAPIKey
        }

        let url = try endpointURL(path: "api/usage/om-usage", queryItems: [
            URLQueryItem(name: "format", value: "json")
        ])

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OmniRouteClientError.invalidResponse
        }

        let decoded = try? JSONDecoder().decode(UsageResponse.self, from: data)
        guard (200..<300).contains(http.statusCode) else {
            let message = decoded?.error?.message ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw OmniRouteClientError.http(status: http.statusCode, message: message)
        }

        guard let decoded else {
            throw OmniRouteClientError.invalidResponse
        }
        guard decoded.allowed else {
            throw OmniRouteClientError.denied(decoded.error?.message ?? "Usage access is not allowed for this API key.")
        }

        return decoded
    }

    public static func normalizedServerURL(_ rawValue: String) throws -> URL {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw OmniRouteClientError.invalidBaseURL
        }

        if !value.contains("://") {
            value = "http://" + value
        }

        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host != nil else {
            throw OmniRouteClientError.invalidBaseURL
        }

        var path = components.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }

        if path == "/v1" {
            path = ""
        } else if path.hasSuffix("/v1") {
            path.removeLast(3)
        }

        components.path = path
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw OmniRouteClientError.invalidBaseURL
        }
        return url
    }

    private func endpointURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else {
            throw OmniRouteClientError.invalidBaseURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, endpointPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.queryItems = queryItems

        guard let url = components.url else {
            throw OmniRouteClientError.invalidBaseURL
        }
        return url
    }
}

public enum OmniRouteClientError: LocalizedError, Equatable {
    case invalidBaseURL
    case missingAPIKey
    case invalidResponse
    case denied(String)
    case http(status: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Enter a valid OmniRoute URL, for example http://localhost:20128."
        case .missingAPIKey:
            return "Enter an OmniRoute API key."
        case .invalidResponse:
            return "OmniRoute returned an unexpected response."
        case .denied(let message):
            return message
        case .http(let status, let message):
            if status == 403 {
                return "\(message) Enable Usage Command for this API key in OmniRoute."
            }
            return "\(message) (HTTP \(status))"
        }
    }
}
