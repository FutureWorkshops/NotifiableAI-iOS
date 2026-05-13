import Foundation

extension NotifiableDecide {
    /// A decoded alert decision returned by ``Engine/decide(domain:candidates:schema:options:)``.
    ///
    /// Host apps with different decision shapes define their own `Codable`
    /// types and pass them as the `schema:` argument. This concrete type is
    /// the supported default and has additional validation rules applied by
    /// the engine after decoding (see ``validate(truncating:)``).
    public struct AlertDecision: Sendable, Codable, Equatable {
        public let shouldAlert: Bool
        public let candidateId: String?
        /// 60-char max — engine truncates with ellipsis if exceeded.
        public let headline: String?
        /// 120-char max — engine truncates with ellipsis if exceeded.
        public let body: String?
        public let priority: Priority
        /// Clamped to `0...86_400` by the engine.
        public let suppressFor: TimeInterval?

        public enum Priority: String, Sendable, Codable {
            case low, medium, high
        }

        public init(
            shouldAlert: Bool,
            candidateId: String?,
            headline: String?,
            body: String?,
            priority: Priority,
            suppressFor: TimeInterval?
        ) {
            self.shouldAlert = shouldAlert
            self.candidateId = candidateId
            self.headline = headline
            self.body = body
            self.priority = priority
            self.suppressFor = suppressFor
        }

        // Field limits used by ``validate(truncating:)`` and the suppression rail.
        static let headlineLimit = 60
        static let bodyLimit = 120
        static let suppressForRange: ClosedRange<TimeInterval> = 0...86_400

        /// Apply post-decoding validation per the PRD §3.4 rules.
        ///
        /// - Throws ``NotifiableDecideError/decisionValidationFailed`` if
        ///   `shouldAlert == true` and any of `candidateId`, `headline`, `body` is
        ///   nil or empty.
        /// - Returns a possibly-truncated/clamped copy of `self`.
        ///   `truncating` is invoked with the original and truncated string so
        ///   the caller can log a warning.
        func validate(truncating: (String, String) -> Void) throws -> AlertDecision {
            if shouldAlert {
                guard let candidateId, !candidateId.isEmpty else {
                    throw NotifiableDecideError.decisionValidationFailed(reason: "shouldAlert=true but candidateId is missing")
                }
                guard let headline, !headline.isEmpty else {
                    throw NotifiableDecideError.decisionValidationFailed(reason: "shouldAlert=true but headline is missing")
                }
                guard let body, !body.isEmpty else {
                    throw NotifiableDecideError.decisionValidationFailed(reason: "shouldAlert=true but body is missing")
                }
                _ = candidateId
                let trimmedHeadline = Self.truncateWithEllipsis(headline, limit: Self.headlineLimit, original: headline, log: truncating)
                let trimmedBody = Self.truncateWithEllipsis(body, limit: Self.bodyLimit, original: body, log: truncating)
                let clampedSuppress = suppressFor.map { min(max($0, Self.suppressForRange.lowerBound), Self.suppressForRange.upperBound) }
                return AlertDecision(
                    shouldAlert: true,
                    candidateId: candidateId,
                    headline: trimmedHeadline,
                    body: trimmedBody,
                    priority: priority,
                    suppressFor: clampedSuppress
                )
            } else {
                let clampedSuppress = suppressFor.map { min(max($0, Self.suppressForRange.lowerBound), Self.suppressForRange.upperBound) }
                return AlertDecision(
                    shouldAlert: false,
                    candidateId: candidateId,
                    headline: headline,
                    body: body,
                    priority: priority,
                    suppressFor: clampedSuppress
                )
            }
        }

        private static func truncateWithEllipsis(
            _ value: String,
            limit: Int,
            original: String,
            log: (String, String) -> Void
        ) -> String {
            guard value.count > limit else { return value }
            guard limit > 1 else { return String(value.prefix(limit)) }
            let truncated = String(value.prefix(limit - 1)) + "…"
            log(original, truncated)
            return truncated
        }
    }
}
