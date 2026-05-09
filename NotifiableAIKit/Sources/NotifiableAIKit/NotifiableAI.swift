import Foundation

/// High-level entry point for the NotifiableAI SDK.
///
/// Configure once at app startup with your server URL and `device_write` API
/// key, then call ``register(pushToken:pushType:appVersion:locale:)`` from
/// `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
///
/// ```swift
/// // In your AppDelegate / @main file.
/// NotifiableAI.configure(
///     baseURL: URL(string: "https://api.notifiable.ai")!,
///     apiKey: "nfk_your_device_write_key"
/// )
///
/// // In didRegisterForRemoteNotificationsWithDeviceToken:
/// let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
/// _ = try await NotifiableAI.register(pushToken: hex)
/// ```
///
/// Subsequent ``update(pushToken:appVersion:locale:pushType:)`` and
/// ``unregister(pushToken:)`` calls automatically use the `device_secret`
/// stored at register time. By default, the secret and device id are persisted
/// to the keychain (`KeychainStorage`); inject your own ``NotifiableAIStorage``
/// to change that.
public enum NotifiableAI {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _config: Config?

    private struct Config {
        let client: NotifiableAIClient
        let storage: NotifiableAIStorage
        let bundle: Bundle
    }

    enum Keys {
        static let deviceSecret = "notifiable.device_secret"
        static let deviceId = "notifiable.device_id"
    }

    /// Configure the SDK. Safe to call multiple times — the latest call wins.
    /// Pass a custom ``NotifiableAIStorage`` if you don't want the default
    /// keychain persistence.
    public static func configure(
        baseURL: URL,
        apiKey: String,
        storage: NotifiableAIStorage? = nil,
        session: URLSession = .shared,
        bundle: Bundle = .main
    ) {
        let resolvedStorage: NotifiableAIStorage
        if let storage {
            resolvedStorage = storage
        } else {
            #if canImport(Security)
            resolvedStorage = KeychainStorage()
            #else
            resolvedStorage = InMemoryStorage()
            #endif
        }
        lock.lock(); defer { lock.unlock() }
        _config = Config(
            client: NotifiableAIClient(baseURL: baseURL, deviceWriteKey: apiKey, session: session),
            storage: resolvedStorage,
            bundle: bundle
        )
    }

    /// Register the device with the NotifiableAI server. Persists the returned
    /// `device_secret` and `id` to storage so later `update` / `unregister`
    /// calls work without further bookkeeping. Returns the full server response.
    @discardableResult
    public static func register(
        pushToken: String,
        pushType: PushType = .alert,
        appVersion: String? = nil,
        locale: String? = nil
    ) async throws -> DeviceResponse {
        let cfg = try config()
        let response = try await cfg.client.registerDevice(
            pushToken: pushToken,
            pushType: pushType,
            appVersion: appVersion ?? Self.defaultAppVersion(bundle: cfg.bundle),
            locale: locale ?? Locale.current.identifier
        )
        if let secret = response.deviceSecret {
            cfg.storage.setString(secret, forKey: Keys.deviceSecret)
        }
        cfg.storage.setString(String(response.id), forKey: Keys.deviceId)
        return response
    }

    /// Update device attributes. Uses the `device_secret` persisted at register time.
    @discardableResult
    public static func update(
        pushToken: String,
        appVersion: String? = nil,
        locale: String? = nil,
        pushType: PushType? = nil
    ) async throws -> DeviceResponse {
        let cfg = try config()
        let secret = try requireDeviceSecret(cfg)
        return try await cfg.client.updateDevice(
            pushToken: pushToken,
            deviceSecret: secret,
            pushType: pushType,
            appVersion: appVersion ?? Self.defaultAppVersion(bundle: cfg.bundle),
            locale: locale ?? Locale.current.identifier
        )
    }

    /// Unregister the device. Clears the persisted `device_secret`/`device_id`
    /// on success.
    public static func unregister(pushToken: String) async throws {
        let cfg = try config()
        let secret = try requireDeviceSecret(cfg)
        try await cfg.client.deleteDevice(pushToken: pushToken, deviceSecret: secret)
        cfg.storage.setString(nil, forKey: Keys.deviceSecret)
        cfg.storage.setString(nil, forKey: Keys.deviceId)
    }

    /// Register a Live Activity. The persisted `device_secret` is updated if
    /// the server issues a fresh one (when this is the first activity for a
    /// freshly-seen push token).
    @discardableResult
    public static func registerLiveActivity(
        activityId: String,
        pushToken: String,
        appVersion: String? = nil,
        locale: String? = nil
    ) async throws -> LiveActivityResponse {
        let cfg = try config()
        let response = try await cfg.client.registerLiveActivity(
            activityId: activityId,
            pushToken: pushToken,
            appVersion: appVersion ?? Self.defaultAppVersion(bundle: cfg.bundle),
            locale: locale ?? Locale.current.identifier
        )
        if let secret = response.deviceSecret {
            cfg.storage.setString(secret, forKey: Keys.deviceSecret)
        }
        return response
    }

    /// End a Live Activity by id.
    public static func endLiveActivity(activityId: String) async throws {
        let cfg = try config()
        let secret = try requireDeviceSecret(cfg)
        try await cfg.client.endLiveActivity(activityId: activityId, deviceSecret: secret)
    }

    /// The persisted `device_secret`, if any.
    public static var deviceSecret: String? {
        (try? config())?.storage.string(forKey: Keys.deviceSecret)
    }

    /// The persisted device id, if any.
    public static var deviceId: Int? {
        guard let s = (try? config())?.storage.string(forKey: Keys.deviceId) else { return nil }
        return Int(s)
    }

    // MARK: - Internals

    private static func config() throws -> Config {
        lock.lock(); defer { lock.unlock() }
        guard let c = _config else {
            throw NotifiableAIError.notConfigured
        }
        return c
    }

    private static func requireDeviceSecret(_ cfg: Config) throws -> String {
        guard let s = cfg.storage.string(forKey: Keys.deviceSecret), !s.isEmpty else {
            throw NotifiableAIError.deviceNotRegistered
        }
        return s
    }

    private static func defaultAppVersion(bundle: Bundle) -> String? {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
