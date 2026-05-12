import Foundation

extension NotifiableAIIntelligence {
    /// Per-call overrides for ``Engine/decide(domain:candidates:schema:options:)``.
    public struct DecideOptions: Sendable {
        public var tokenBudget: Int
        public var includeDecayedPreferences: Bool
        public var systemPromptOverride: String?
        public var temperature: Double

        public init(
            tokenBudget: Int = 500,
            includeDecayedPreferences: Bool = false,
            systemPromptOverride: String? = nil,
            temperature: Double = 0.2
        ) {
            self.tokenBudget = tokenBudget
            self.includeDecayedPreferences = includeDecayedPreferences
            self.systemPromptOverride = systemPromptOverride
            self.temperature = temperature
        }
    }
}
