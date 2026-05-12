import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

extension NotifiableIntelligence {
    /// ``ModelAdapter`` that runs decisions through Apple's on-device
    /// Foundation Models framework.
    ///
    /// On older OSes (or platforms where `FoundationModels` is unavailable)
    /// every call throws ``NotifiableIntelligenceError/foundationModelUnavailable``.
    public struct FoundationModelAdapter: ModelAdapter {
        public init() {}

        public func decide<Schema: Decodable & Sendable>(
            systemPrompt: String,
            contextBlock: String,
            schema: Schema.Type,
            options: ModelOptions
        ) async throws -> Schema {
            #if canImport(FoundationModels)
            if #available(iOS 26, macOS 26, *) {
                return try await Self.decideUsingFoundationModels(
                    systemPrompt: systemPrompt,
                    contextBlock: contextBlock,
                    schema: schema,
                    options: options
                )
            }
            #endif
            throw NotifiableIntelligenceError.foundationModelUnavailable
        }

        #if canImport(FoundationModels)
        @available(iOS 26, macOS 26, *)
        private static func decideUsingFoundationModels<Schema: Decodable & Sendable>(
            systemPrompt: String,
            contextBlock: String,
            schema: Schema.Type,
            options: ModelOptions
        ) async throws -> Schema {
            let model = SystemLanguageModel.default
            guard model.availability == .available else {
                throw NotifiableIntelligenceError.foundationModelUnavailable
            }

            let session = LanguageModelSession(model: model, instructions: systemPrompt)
            let prompt = "Given the following context, return the structured decision.\n\n\(contextBlock)"
            let generationOptions = GenerationOptions(temperature: options.temperature, maximumResponseTokens: options.maxOutputTokens)

            // Ask for raw text and decode against the supplied schema. This
            // works whether or not the schema is annotated `@Generable`. We
            // keep the JSON path explicit since the kit's caller-facing
            // schema (`AlertDecision`) is a plain `Codable`.
            let response = try await session.respond(to: prompt, options: generationOptions)
            return try decodeJSON(response.content, as: schema)
        }
        #endif

        private static func decodeJSON<Schema: Decodable>(_ text: String, as type: Schema.Type) throws -> Schema {
            // Models often wrap JSON in markdown fencing. Strip it.
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let json: String
            if trimmed.hasPrefix("```") {
                let withoutOpening = trimmed.replacingOccurrences(of: #"^```(?:json)?\n?"#, with: "", options: .regularExpression)
                json = withoutOpening.replacingOccurrences(of: #"\n?```$"#, with: "", options: .regularExpression)
            } else {
                json = trimmed
            }
            guard let data = json.data(using: .utf8) else {
                throw NotifiableIntelligenceError.decisionValidationFailed(reason: "Model response was not UTF-8")
            }
            do {
                return try JSONDecoder().decode(Schema.self, from: data)
            } catch {
                throw NotifiableIntelligenceError.decisionValidationFailed(reason: "Model response JSON did not match schema: \(error)")
            }
        }
    }
}
