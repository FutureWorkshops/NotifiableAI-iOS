import Foundation

public enum PushType: String, Sendable, Codable, CaseIterable {
    case alert
    case background
    case voip
    case complication
    case fileprovider
    case mdm
    case liveactivity
    case pushtotalk
}

public struct DeviceResponse: Decodable, Sendable {
    public let id: Int
    public let pushToken: String
    public let pushType: String?
    public let appVersion: String?
    public let locale: String?
    public let lastSeenAt: Date?
    /// Only present on `registerDevice`. Persist this — it's required for update/delete.
    public let deviceSecret: String?

    enum CodingKeys: String, CodingKey {
        case id
        case pushToken = "push_token"
        case pushType = "push_type"
        case appVersion = "app_version"
        case locale
        case lastSeenAt = "last_seen_at"
        case deviceSecret = "device_secret"
    }
}

public struct LiveActivityResponse: Decodable, Sendable {
    public let id: Int
    public let activityId: String
    public let deviceId: Int
    public let pushToken: String
    public let startedAt: Date?
    public let endedAt: Date?
    public let deviceSecret: String?

    enum CodingKeys: String, CodingKey {
        case id
        case activityId = "activity_id"
        case deviceId = "device_id"
        case pushToken = "push_token"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case deviceSecret = "device_secret"
    }
}

public enum NotifiableRemoteError: Error, CustomStringConvertible {
    case missingAPIKey(String)
    case invalidResponse
    case http(status: Int, message: String?)
    case decoding(Error)
    case notConfigured
    case deviceNotRegistered

    public var description: String {
        switch self {
        case .missingAPIKey(let kind): return "Missing \(kind) API key"
        case .invalidResponse: return "Invalid response"
        case .http(let status, let msg): return "HTTP \(status)\(msg.map { ": \($0)" } ?? "")"
        case .decoding(let e): return "Decoding error: \(e)"
        case .notConfigured: return "NotifiableRemote.configure(...) has not been called"
        case .deviceNotRegistered: return "Device not registered: call NotifiableRemote.register first"
        }
    }
}
