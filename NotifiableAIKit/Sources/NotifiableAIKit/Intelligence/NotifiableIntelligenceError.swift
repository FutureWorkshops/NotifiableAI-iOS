import Foundation

/// Errors thrown by ``NotifiableIntelligence/Engine`` and its collaborators.
///
/// Sits at module top level, parallel to ``NotifiableAIError``, so `throws`
/// clauses stay readable.
public enum NotifiableIntelligenceError: Error, Sendable, CustomStringConvertible {
    case foundationModelUnavailable
    case decisionValidationFailed(reason: String)
    case tokenBudgetExceeded(requested: Int, limit: Int)
    case storeUnavailable(underlying: Error)

    public var description: String {
        switch self {
        case .foundationModelUnavailable:
            return "Foundation Models is unavailable on this device. Apple Intelligence must be enabled."
        case .decisionValidationFailed(let reason):
            return "Decision validation failed: \(reason)"
        case .tokenBudgetExceeded(let requested, let limit):
            return "Token budget exceeded: requested \(requested), limit \(limit)"
        case .storeUnavailable(let underlying):
            return "Preference store unavailable: \(underlying)"
        }
    }
}
