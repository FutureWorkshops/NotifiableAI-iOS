import Foundation
#if canImport(Security)
import Security
#endif

/// Persists the small bits of state NotifiableAI needs across launches:
/// the `device_secret` returned by `register`, and the device's row id.
///
/// The default implementation is a keychain wrapper. Tests inject an
/// in-memory store via `NotifiableAI.configure(... storage:)`.
public protocol NotifiableAIStorage: Sendable {
    func string(forKey key: String) -> String?
    func setString(_ value: String?, forKey key: String)
}

#if canImport(Security)
public struct KeychainStorage: NotifiableAIStorage {
    public let service: String

    public init(service: String = "ai.notifiable.kit") {
        self.service = service
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    public func string(forKey key: String) -> String? {
        var q = baseQuery(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    public func setString(_ value: String?, forKey key: String) {
        let q = baseQuery(key)
        SecItemDelete(q as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var add = q
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
#endif

/// In-memory storage for tests and previews.
public final class InMemoryStorage: NotifiableAIStorage, @unchecked Sendable {
    private var values: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func string(forKey key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }

    public func setString(_ value: String?, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
    }
}
