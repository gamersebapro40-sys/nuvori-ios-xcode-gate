import Foundation
import Security

// R3.5.22.3.4.1 — single credential persistence owner.
// Token acquisition/refresh remains in the ONE NUVORIAPIClient.
enum NUVORIKeychainError: Error {
    case unexpectedStatus(OSStatus)
}

final class NUVORIKeychainStore {
    static let shared = NUVORIKeychainStore()

    private let service: String
    private let accessAccount = "nuvori.native.bearer-access-token"
    private let refreshAccount = "nuvori.native.bearer-refresh-token"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.nuvori.app") {
        self.service = service
    }

    private func readSecret(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveSecret(_ secret: String, account: String) throws {
        let data = Data(secret.utf8)
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let update = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw NUVORIKeychainError.unexpectedStatus(update) }

        var add = lookup
        for (key, value) in attributes { add[key] = value }
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw NUVORIKeychainError.unexpectedStatus(status) }
    }

    private func deleteSecret(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NUVORIKeychainError.unexpectedStatus(status)
        }
    }

    func readAccessToken() -> String? { readSecret(account: accessAccount) }
    func readRefreshToken() -> String? { readSecret(account: refreshAccount) }

    func saveAccessToken(_ token: String) throws { try saveSecret(token, account: accessAccount) }
    func saveRefreshToken(_ token: String) throws { try saveSecret(token, account: refreshAccount) }

    func saveTokenPair(accessToken: String, refreshToken: String) throws {
        do {
            try saveAccessToken(accessToken)
            try saveRefreshToken(refreshToken)
        } catch {
            try? deleteTokenPair()
            throw error
        }
    }

    func deleteAccessToken() throws { try deleteSecret(account: accessAccount) }
    func deleteRefreshToken() throws { try deleteSecret(account: refreshAccount) }

    func deleteTokenPair() throws {
        var firstError: Error?
        do { try deleteAccessToken() } catch { firstError = error }
        do { try deleteRefreshToken() } catch { if firstError == nil { firstError = error } }
        if let firstError { throw firstError }
    }
}
