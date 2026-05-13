import Foundation

/// Pure given inputs. Snapshot-testable. Internal to the package.
struct ContextAssembler: Sendable {
    typealias Preference = NotifiableDecide.Preference
    typealias CandidateEvent = NotifiableDecide.CandidateEvent
    typealias RecordedAlert = NotifiableDecide.RecordedAlert

    let tokenizer: Tokenizer
    let now: @Sendable () -> Date

    init(tokenizer: Tokenizer = .default, now: @escaping @Sendable () -> Date = { Date() }) {
        self.tokenizer = tokenizer
        self.now = now
    }

    func assemble(
        domain: String,
        preferences: [Preference],
        candidates: [CandidateEvent],
        recentAlerts: [RecordedAlert],
        budget: Int,
        includeDecayed: Bool
    ) -> AssembledContext {
        let now = self.now()

        // 1. Filter preferences by decay flag and ttl expiry.
        let filtered = preferences.filter { pref in
            if pref.confidence == .decayed && !includeDecayed { return false }
            if pref.isExpired(at: now) { return false }
            return true
        }

        // 2. Sort: explicit before inferred (before decayed), then by
        //    lastConfirmedAt descending (most recently confirmed first).
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence < rhs.confidence
            }
            let l = lhs.lastConfirmedAt ?? .distantPast
            let r = rhs.lastConfirmedAt ?? .distantPast
            return l > r
        }

        // 3. Filter recent alerts to the last hour.
        let oneHourAgo = now.addingTimeInterval(-3_600)
        let alertsInWindow = recentAlerts.filter { $0.shownAt >= oneHourAgo }

        // Render with all preferences, then drop tail entries one at a time
        // while over budget. The order above guarantees the tail is the
        // lowest-confidence, oldest preference.
        var kept = sorted
        var dropped: [Preference] = []
        var xml = render(preferences: kept, alerts: alertsInWindow, candidates: candidates)
        var tokens = tokenizer.estimate(xml)
        while tokens > budget && !kept.isEmpty {
            dropped.append(kept.removeLast())
            xml = render(preferences: kept, alerts: alertsInWindow, candidates: candidates)
            tokens = tokenizer.estimate(xml)
        }

        return AssembledContext(xml: xml, droppedPreferences: dropped, estimatedTokens: tokens)
    }

    private func render(
        preferences: [Preference],
        alerts: [RecordedAlert],
        candidates: [CandidateEvent]
    ) -> String {
        let dateFormatter = ISO8601DateFormatter.intelligenceFormatter()
        var out = "<context>\n"

        out.append("  <preferences>\n")
        for p in preferences {
            let domain = XMLEscaper.escape(p.domain)
            let key = XMLEscaper.escape(p.key)
            let conf = p.confidence.rawValue
            let text = XMLEscaper.escape(p.value.xmlText)
            out.append("    <preference domain=\"\(domain)\" key=\"\(key)\" confidence=\"\(conf)\">\(text)</preference>\n")
        }
        out.append("  </preferences>\n")

        out.append("  <recent_alerts>\n")
        for a in alerts {
            let subj = XMLEscaper.escape(a.subject)
            let type = XMLEscaper.escape(a.type)
            let at = dateFormatter.string(from: a.shownAt)
            out.append("    <alert subject=\"\(subj)\" type=\"\(type)\" at=\"\(at)\"/>\n")
        }
        out.append("  </recent_alerts>\n")

        out.append("  <candidates>\n")
        for c in candidates {
            let id = XMLEscaper.escape(c.id)
            let subj = XMLEscaper.escape(c.subject)
            let type = XMLEscaper.escape(c.type)
            let occursAt = dateFormatter.string(from: c.occursAt)
            let sig = String(format: "%.2f", c.significance)
            if c.attributes.isEmpty {
                out.append("    <event id=\"\(id)\" subject=\"\(subj)\" type=\"\(type)\" significance=\"\(sig)\" occursAt=\"\(occursAt)\"/>\n")
            } else {
                out.append("    <event id=\"\(id)\" subject=\"\(subj)\" type=\"\(type)\" significance=\"\(sig)\" occursAt=\"\(occursAt)\">\n")
                // Stable order: sorted keys.
                for key in c.attributes.keys.sorted() {
                    guard let v = c.attributes[key] else { continue }
                    let k = XMLEscaper.escape(key)
                    let t = v.xmlTypeToken
                    let text = XMLEscaper.escape(v.xmlText)
                    out.append("      <attribute key=\"\(k)\" type=\"\(t)\">\(text)</attribute>\n")
                }
                out.append("    </event>\n")
            }
        }
        out.append("  </candidates>\n")

        out.append("</context>")
        return out
    }
}

struct AssembledContext: Sendable {
    let xml: String
    let droppedPreferences: [NotifiableDecide.Preference]
    let estimatedTokens: Int
}

extension ISO8601DateFormatter {
    /// Each call creates a fresh formatter. `ISO8601DateFormatter` isn't
    /// `Sendable`, and constructing one is cheap compared with what the rest
    /// of the pipeline does — sharing a single instance behind locks isn't
    /// worth the complexity here.
    static func intelligenceFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }
}
