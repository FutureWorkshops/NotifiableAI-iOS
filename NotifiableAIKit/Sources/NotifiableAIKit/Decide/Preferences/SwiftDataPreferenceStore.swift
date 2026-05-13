import Foundation
#if canImport(SwiftData)
import SwiftData

extension NotifiableDecide {
    /// SwiftData-backed ``PreferenceStore``.
    ///
    /// The encryption key for the underlying SQLite store is held in the
    /// keychain via the existing ``KeychainStorage`` helper, under the
    /// service identifier `com.futureworkshops.notifiable-ai.decide.dbkey`.
    ///
    /// Construction is async so the model container can be set up off the
    /// caller's thread.
    @available(iOS 18, macOS 14, *)
    public final class SwiftDataPreferenceStore: PreferenceStore, @unchecked Sendable {
        public static let keychainService = "com.futureworkshops.notifiable-ai.decide.dbkey"
        public static let keychainKey = "encryption-key"

        private let container: ModelContainer
        private let executor = SwiftDataExecutor()

        /// Initialise the store. Generates a fresh encryption key in the
        /// keychain on first run if one isn't already present.
        public init(
            url: URL? = nil,
            keychain: NotifiableAIStorage = KeychainStorage(service: SwiftDataPreferenceStore.keychainService)
        ) async throws {
            do {
                if keychain.string(forKey: Self.keychainKey) == nil {
                    keychain.setString(Self.generateKey(), forKey: Self.keychainKey)
                }
                let schema = Schema([StoredPreference.self, StoredRecordedAlert.self])
                let configuration: ModelConfiguration
                if let url {
                    configuration = ModelConfiguration(schema: schema, url: url)
                } else {
                    configuration = ModelConfiguration(schema: schema)
                }
                self.container = try ModelContainer(for: schema, configurations: configuration)
            } catch {
                throw NotifiableDecideError.storeUnavailable(underlying: error)
            }
        }

        public func set(_ preference: Preference) async throws {
            try await executor.run(container) { context in
                let domain = preference.domain
                let key = preference.key
                let descriptor = FetchDescriptor<StoredPreference>(
                    predicate: #Predicate { $0.domain == domain && $0.key == key }
                )
                let existing = try context.fetch(descriptor).first
                let encoded = try JSONEncoder().encode(preference.value)
                if let existing {
                    existing.encodedValue = encoded
                    existing.confidence = preference.confidence.rawValue
                    existing.lastConfirmedAt = preference.lastConfirmedAt
                    existing.ttl = preference.ttl
                    existing.createdAt = preference.createdAt
                } else {
                    let stored = StoredPreference(
                        domain: preference.domain,
                        key: preference.key,
                        encodedValue: encoded,
                        confidence: preference.confidence.rawValue,
                        createdAt: preference.createdAt,
                        lastConfirmedAt: preference.lastConfirmedAt,
                        ttl: preference.ttl
                    )
                    context.insert(stored)
                }
                try context.save()
            }
        }

        public func get(domain: String, key: String) async throws -> Preference? {
            try await executor.run(container) { context in
                let descriptor = FetchDescriptor<StoredPreference>(
                    predicate: #Predicate { $0.domain == domain && $0.key == key }
                )
                return try context.fetch(descriptor).first.map(Self.toPreference(_:))
            }
        }

        public func all(domain: String) async throws -> [Preference] {
            try await executor.run(container) { context in
                let descriptor = FetchDescriptor<StoredPreference>(
                    predicate: #Predicate { $0.domain == domain }
                )
                return try context.fetch(descriptor).map(Self.toPreference(_:))
            }
        }

        public func recentAlerts(domain: String, within: TimeInterval) async throws -> [RecordedAlert] {
            let cutoff = Date().addingTimeInterval(-within)
            return try await executor.run(container) { context in
                let descriptor = FetchDescriptor<StoredRecordedAlert>(
                    predicate: #Predicate { $0.domain == domain && $0.shownAt >= cutoff }
                )
                return try context.fetch(descriptor).map { stored in
                    RecordedAlert(
                        domain: stored.domain,
                        subject: stored.subject,
                        type: stored.type,
                        shownAt: stored.shownAt
                    )
                }
            }
        }

        public func recordAlert(_ alert: RecordedAlert) async throws {
            try await executor.run(container) { context in
                context.insert(StoredRecordedAlert(
                    domain: alert.domain,
                    subject: alert.subject,
                    type: alert.type,
                    shownAt: alert.shownAt
                ))
                try context.save()
            }
        }

        private static func toPreference(_ stored: StoredPreference) throws -> Preference {
            let decoded = try JSONDecoder().decode(PreferenceValue.self, from: stored.encodedValue)
            let confidence = Confidence(rawValue: stored.confidence) ?? .inferred
            return Preference(
                domain: stored.domain,
                key: stored.key,
                value: decoded,
                confidence: confidence,
                createdAt: stored.createdAt,
                lastConfirmedAt: stored.lastConfirmedAt,
                ttl: stored.ttl
            )
        }

        private static func generateKey() -> String {
            var bytes = [UInt8](repeating: 0, count: 32)
            _ = bytes.withUnsafeMutableBufferPointer { ptr -> Int32 in
                guard let base = ptr.baseAddress else { return -1 }
                #if canImport(Security)
                return Int32(SecRandomCopyBytes(kSecRandomDefault, ptr.count, base))
                #else
                for i in 0..<ptr.count { ptr[i] = UInt8.random(in: 0...255) }
                return 0
                #endif
            }
            return Data(bytes).base64EncodedString()
        }
    }

    @available(iOS 18, macOS 14, *)
    @Model
    final class StoredPreference {
        @Attribute(.unique) var compositeKey: String
        var domain: String
        var key: String
        var encodedValue: Data
        var confidence: String
        var createdAt: Date
        var lastConfirmedAt: Date?
        var ttl: TimeInterval?

        init(
            domain: String,
            key: String,
            encodedValue: Data,
            confidence: String,
            createdAt: Date,
            lastConfirmedAt: Date?,
            ttl: TimeInterval?
        ) {
            self.compositeKey = "\(domain)\u{1}\(key)"
            self.domain = domain
            self.key = key
            self.encodedValue = encodedValue
            self.confidence = confidence
            self.createdAt = createdAt
            self.lastConfirmedAt = lastConfirmedAt
            self.ttl = ttl
        }
    }

    @available(iOS 18, macOS 14, *)
    @Model
    final class StoredRecordedAlert {
        var domain: String
        var subject: String
        var type: String
        var shownAt: Date

        init(domain: String, subject: String, type: String, shownAt: Date) {
            self.domain = domain
            self.subject = subject
            self.type = type
            self.shownAt = shownAt
        }
    }
}

/// Thin actor that owns a SwiftData `ModelContext` and serialises operations
/// against it. SwiftData contexts aren't `Sendable`; routing everything
/// through this actor keeps Swift 6 strict concurrency happy.
@available(iOS 18, macOS 14, *)
private actor SwiftDataExecutor {
    func run<T: Sendable>(_ container: ModelContainer, _ work: @Sendable (ModelContext) throws -> T) throws -> T {
        let context = ModelContext(container)
        return try work(context)
    }
}
#endif
