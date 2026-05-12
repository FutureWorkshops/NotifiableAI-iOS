import Foundation

extension NotifiableAIIntelligence {
    /// A typed preference belonging to a domain.
    public struct Preference: Sendable, Codable, Equatable {
        public let domain: String
        public let key: String
        public let value: PreferenceValue
        public let confidence: Confidence
        public let createdAt: Date
        public let lastConfirmedAt: Date?
        public let ttl: TimeInterval?

        public init(
            domain: String,
            key: String,
            value: PreferenceValue,
            confidence: Confidence,
            createdAt: Date,
            lastConfirmedAt: Date? = nil,
            ttl: TimeInterval? = nil
        ) {
            self.domain = domain
            self.key = key
            self.value = value
            self.confidence = confidence
            self.createdAt = createdAt
            self.lastConfirmedAt = lastConfirmedAt
            self.ttl = ttl
        }

        /// `true` if the preference has expired against `now` per its `ttl`.
        func isExpired(at now: Date) -> Bool {
            guard let ttl else { return false }
            return now.timeIntervalSince(createdAt) > ttl
        }
    }

    public enum PreferenceValue: Sendable, Codable, Equatable {
        case string(String)
        case stringList([String])
        case number(Double)
        case bool(Bool)
        case range(ClosedRange<Double>)
        case timeWindow(start: DateComponents, end: DateComponents)

        // Codable: tagged union to round-trip the enum.
        private enum CodingKeys: String, CodingKey { case kind, value, lower, upper, start, end }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .string(let s):
                try c.encode("string", forKey: .kind)
                try c.encode(s, forKey: .value)
            case .stringList(let xs):
                try c.encode("stringList", forKey: .kind)
                try c.encode(xs, forKey: .value)
            case .number(let n):
                try c.encode("number", forKey: .kind)
                try c.encode(n, forKey: .value)
            case .bool(let b):
                try c.encode("bool", forKey: .kind)
                try c.encode(b, forKey: .value)
            case .range(let r):
                try c.encode("range", forKey: .kind)
                try c.encode(r.lowerBound, forKey: .lower)
                try c.encode(r.upperBound, forKey: .upper)
            case .timeWindow(let start, let end):
                try c.encode("timeWindow", forKey: .kind)
                try c.encode(start, forKey: .start)
                try c.encode(end, forKey: .end)
            }
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try c.decode(String.self, forKey: .kind)
            switch kind {
            case "string":
                self = .string(try c.decode(String.self, forKey: .value))
            case "stringList":
                self = .stringList(try c.decode([String].self, forKey: .value))
            case "number":
                self = .number(try c.decode(Double.self, forKey: .value))
            case "bool":
                self = .bool(try c.decode(Bool.self, forKey: .value))
            case "range":
                let lo = try c.decode(Double.self, forKey: .lower)
                let hi = try c.decode(Double.self, forKey: .upper)
                self = .range(lo...hi)
            case "timeWindow":
                let s = try c.decode(DateComponents.self, forKey: .start)
                let e = try c.decode(DateComponents.self, forKey: .end)
                self = .timeWindow(start: s, end: e)
            default:
                throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "Unknown PreferenceValue kind: \(kind)")
            }
        }

        /// Rendered representation used inside `<preference>` element text.
        var xmlText: String {
            switch self {
            case .string(let s): return s
            case .stringList(let xs): return xs.joined(separator: ", ")
            case .number(let n): return String(n)
            case .bool(let b): return b ? "true" : "false"
            case .range(let r): return "\(r.lowerBound)..\(r.upperBound)"
            case .timeWindow(let start, let end):
                func hhmm(_ c: DateComponents) -> String {
                    let h = c.hour ?? 0
                    let m = c.minute ?? 0
                    return String(format: "%02d:%02d", h, m)
                }
                return "\(hhmm(start))-\(hhmm(end))"
            }
        }
    }

    /// How the engine should weigh a preference.
    public enum Confidence: String, Sendable, Codable, Comparable {
        case explicit, inferred, decayed

        /// `explicit < inferred < decayed` reads "more confident is smaller",
        /// which makes ascending sorts surface high-confidence first.
        private var rank: Int {
            switch self {
            case .explicit: return 0
            case .inferred: return 1
            case .decayed: return 2
            }
        }

        public static func < (lhs: Confidence, rhs: Confidence) -> Bool {
            lhs.rank < rhs.rank
        }
    }
}
