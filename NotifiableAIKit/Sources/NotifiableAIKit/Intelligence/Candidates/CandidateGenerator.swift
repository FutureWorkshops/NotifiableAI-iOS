import Foundation

extension NotifiableIntelligence {
    /// Host-app supplied source of candidate events for a single domain.
    ///
    /// The Intelligence layer does not yet schedule generators — host apps
    /// call ``generateCandidates()`` themselves and pass the result to
    /// ``Engine/decide(domain:candidates:schema:options:)``. The protocol
    /// exists to enforce a consistent shape across host implementations and
    /// to permit future scheduling without an API break.
    public protocol CandidateGenerator: Sendable {
        var domain: String { get }
        func generateCandidates() async throws -> [CandidateEvent]
    }
}
