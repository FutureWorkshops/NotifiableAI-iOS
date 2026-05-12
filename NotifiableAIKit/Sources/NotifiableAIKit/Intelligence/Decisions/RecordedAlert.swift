import Foundation

extension NotifiableIntelligence {
    /// An alert the engine actually decided to surface.
    ///
    /// Recorded via ``PreferenceStore/recordAlert(_:)`` so future `decide`
    /// calls can dedupe and the suppression safety rail can fire.
    public struct RecordedAlert: Sendable, Codable, Equatable {
        public let domain: String
        public let subject: String
        public let type: String
        public let shownAt: Date

        public init(domain: String, subject: String, type: String, shownAt: Date) {
            self.domain = domain
            self.subject = subject
            self.type = type
            self.shownAt = shownAt
        }
    }
}
