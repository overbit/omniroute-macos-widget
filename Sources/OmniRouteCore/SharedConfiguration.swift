import Foundation
import Security

public enum OmniRouteSharedConfiguration {
    public static let appGroup = "group.com.overbit.OmniRouteWidget"
    public static let keychainService = "com.overbit.OmniRouteWidget"
    public static let keychainAccount = "omniroute-api-key"
    public static let keychainAccessGroup = appGroup
    public static let defaultBaseURL = "http://localhost:20128"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    public static func loadBaseURL() -> String {
        defaults.string(forKey: "omnirouteBaseURL") ?? defaultBaseURL
    }

    public static func saveBaseURL(_ value: String) {
        defaults.set(value, forKey: "omnirouteBaseURL")
    }

    public static func loadAPIKey() -> String {
        if let value = readKeychain(useSharedGroup: true) {
            return value
        }
        return readKeychain(useSharedGroup: false) ?? ""
    }

    public static func saveAPIKey(_ value: String) throws {
        let data = Data(value.utf8)
        let sharedStatus = upsertKeychain(data: data, useSharedGroup: true)

        if sharedStatus == errSecSuccess {
            return
        }

        if sharedStatus == errSecMissingEntitlement {
            let fallbackStatus = upsertKeychain(data: data, useSharedGroup: false)
            guard fallbackStatus == errSecSuccess else {
                throw KeychainError.status(fallbackStatus)
            }
            return
        }

        throw KeychainError.status(sharedStatus)
    }

    private static func readKeychain(useSharedGroup: Bool) -> String? {
        var query = baseQuery(useSharedGroup: useSharedGroup)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private static func upsertKeychain(data: Data, useSharedGroup: Bool) -> OSStatus {
        let query = baseQuery(useSharedGroup: useSharedGroup)
        let attributes = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return errSecSuccess
        }
        if updateStatus != errSecItemNotFound {
            return updateStatus
        }

        var item = query
        item[kSecValueData as String] = data
        return SecItemAdd(item as CFDictionary, nil)
    }

    private static func baseQuery(useSharedGroup: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        if useSharedGroup {
            query[kSecAttrAccessGroup as String] = keychainAccessGroup
        }
        return query
    }

    public enum KeychainError: LocalizedError {
        case status(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .status(let status):
                return SecCopyErrorMessageString(status, nil) as String?
                    ?? "Keychain error \(status)"
            }
        }
    }
}
