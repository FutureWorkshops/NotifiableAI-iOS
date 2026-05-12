import Foundation

extension NotifiableIntelligence {
    /// A potentially-alertable event surfaced by the host app.
    ///
    /// The Intelligence layer does not generate candidates itself; the host
    /// app's `CandidateGenerator` (or equivalent) produces these and feeds
    /// them to ``Engine/decide(domain:candidates:schema:options:)``.
    public struct CandidateEvent: Sendable, Codable, Identifiable, Equatable {
        public let id: String
        /// Domain-specific event type, e.g. "teeingOff", "eagle".
        public let type: String
        /// Domain-specific subject identifier, e.g. a player id.
        public let subject: String
        public let occursAt: Date
        /// Host-supplied heuristic, clamped to `0...1`.
        public let significance: Double
        /// Freeform typed attributes. Rendered as XML attributes by the
        /// internal `ContextAssembler`.
        public let attributes: [String: AttributeValue]

        public init(
            id: String,
            type: String,
            subject: String,
            occursAt: Date,
            significance: Double,
            attributes: [String: AttributeValue] = [:]
        ) {
            self.id = id
            self.type = type
            self.subject = subject
            self.occursAt = occursAt
            self.significance = min(max(significance, 0), 1)
            self.attributes = attributes
        }
    }

    /// Typed value for a candidate event attribute.
    public enum AttributeValue: Sendable, Codable, Equatable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case duration(TimeInterval)

        // Codable: tagged union via { "kind": "...", "value": ... }
        private enum CodingKeys: String, CodingKey { case kind, value }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .string(let s):
                try c.encode("string", forKey: .kind)
                try c.encode(s, forKey: .value)
            case .number(let n):
                try c.encode("number", forKey: .kind)
                try c.encode(n, forKey: .value)
            case .bool(let b):
                try c.encode("bool", forKey: .kind)
                try c.encode(b, forKey: .value)
            case .duration(let d):
                try c.encode("duration", forKey: .kind)
                try c.encode(d, forKey: .value)
            }
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try c.decode(String.self, forKey: .kind)
            switch kind {
            case "string": self = .string(try c.decode(String.self, forKey: .value))
            case "number": self = .number(try c.decode(Double.self, forKey: .value))
            case "bool": self = .bool(try c.decode(Bool.self, forKey: .value))
            case "duration": self = .duration(try c.decode(TimeInterval.self, forKey: .value))
            default:
                throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "Unknown AttributeValue kind: \(kind)")
            }
        }

        /// XML attribute `type=` token used by the context assembler.
        var xmlTypeToken: String {
            switch self {
            case .string: return "string"
            case .number: return "number"
            case .bool: return "bool"
            case .duration: return "duration"
            }
        }

        /// Stringified value used inside `<attribute>` element text.
        var xmlText: String {
            switch self {
            case .string(let s): return s
            case .number(let n): return String(n)
            case .bool(let b): return b ? "true" : "false"
            case .duration(let d): return String(d)
            }
        }
    }
}
