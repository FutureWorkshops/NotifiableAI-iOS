import Foundation

extension NotifiableDecide {
    /// Persistent backing for preferences and the recent-alert ledger.
    ///
    /// Conforming types must be safe to call from any async context — the
    /// engine treats the store as a black box and assumes its own concurrency
    /// is handled internally.
    public protocol PreferenceStore: Sendable {
        func set(_ preference: Preference) async throws
        func get(domain: String, key: String) async throws -> Preference?
        func all(domain: String) async throws -> [Preference]
        func recentAlerts(domain: String, within: TimeInterval) async throws -> [RecordedAlert]
        func recordAlert(_ alert: RecordedAlert) async throws
    }
}
