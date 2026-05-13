import Foundation

extension NotifiableDecide {
    /// Actor-isolated, non-persistent ``PreferenceStore`` implementation.
    ///
    /// Used in tests and demo / preview contexts. State vanishes when the
    /// actor goes out of scope.
    public actor InMemoryPreferenceStore: PreferenceStore {
        private var preferences: [Key: Preference] = [:]
        private var alerts: [RecordedAlert] = []

        public init() {}

        public func set(_ preference: Preference) async throws {
            preferences[Key(domain: preference.domain, key: preference.key)] = preference
        }

        public func get(domain: String, key: String) async throws -> Preference? {
            preferences[Key(domain: domain, key: key)]
        }

        public func all(domain: String) async throws -> [Preference] {
            preferences.values.filter { $0.domain == domain }
        }

        public func recentAlerts(domain: String, within: TimeInterval) async throws -> [RecordedAlert] {
            let cutoff = Date().addingTimeInterval(-within)
            return alerts.filter { $0.domain == domain && $0.shownAt >= cutoff }
        }

        public func recordAlert(_ alert: RecordedAlert) async throws {
            alerts.append(alert)
        }

        private struct Key: Hashable {
            let domain: String
            let key: String
        }
    }
}
