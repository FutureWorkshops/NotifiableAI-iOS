import Foundation

extension NotifiableIntelligence {
    /// Pluggable backend that performs the actual model call given a
    /// pre-rendered XML context block.
    public protocol ModelAdapter: Sendable {
        func decide<Schema: Decodable & Sendable>(
            systemPrompt: String,
            contextBlock: String,
            schema: Schema.Type,
            options: ModelOptions
        ) async throws -> Schema
    }

    public struct ModelOptions: Sendable {
        public var temperature: Double
        public var maxOutputTokens: Int

        public init(temperature: Double = 0.2, maxOutputTokens: Int = 256) {
            self.temperature = temperature
            self.maxOutputTokens = maxOutputTokens
        }
    }
}
