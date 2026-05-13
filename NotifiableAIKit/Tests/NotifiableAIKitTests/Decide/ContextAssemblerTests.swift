import Testing
import Foundation
@testable import NotifiableAIKit

@Suite struct ContextAssemblerTests {
    typealias Pref = NotifiableDecide.Preference
    typealias Cand = NotifiableDecide.CandidateEvent
    typealias Alert = NotifiableDecide.RecordedAlert

    /// Fixed reference date so snapshots stay deterministic.
    private static let now = Date(timeIntervalSince1970: 1_770_000_000) // 2026-02-02T02:40:00Z
    private static let assembler = ContextAssembler(now: { ContextAssemblerTests.now })

    // MARK: - Filtering / sorting

    @Test func dropsDecayedPreferencesByDefault() {
        let prefs = [
            Pref(domain: "d", key: "k1", value: .string("v1"), confidence: .explicit, createdAt: Self.now),
            Pref(domain: "d", key: "k2", value: .string("v2"), confidence: .decayed, createdAt: Self.now)
        ]
        let ctx = Self.assembler.assemble(domain: "d", preferences: prefs, candidates: [], recentAlerts: [], budget: 10_000, includeDecayed: false)
        #expect(ctx.xml.contains("k1"))
        #expect(!ctx.xml.contains("k2"))
    }

    @Test func keepsDecayedPreferencesWhenOptedIn() {
        let prefs = [
            Pref(domain: "d", key: "k1", value: .string("v"), confidence: .decayed, createdAt: Self.now)
        ]
        let ctx = Self.assembler.assemble(domain: "d", preferences: prefs, candidates: [], recentAlerts: [], budget: 10_000, includeDecayed: true)
        #expect(ctx.xml.contains("k1"))
    }

    @Test func dropsExpiredPreferences() {
        let old = Self.now.addingTimeInterval(-10_000)
        let prefs = [
            Pref(domain: "d", key: "fresh", value: .string("v"), confidence: .explicit, createdAt: Self.now),
            Pref(domain: "d", key: "stale", value: .string("v"), confidence: .explicit, createdAt: old, ttl: 100)
        ]
        let ctx = Self.assembler.assemble(domain: "d", preferences: prefs, candidates: [], recentAlerts: [], budget: 10_000, includeDecayed: false)
        #expect(ctx.xml.contains("fresh"))
        #expect(!ctx.xml.contains("stale"))
    }

    @Test func sortsExplicitBeforeInferred() {
        let prefs = [
            Pref(domain: "d", key: "inferredOne", value: .string("v"), confidence: .inferred, createdAt: Self.now),
            Pref(domain: "d", key: "explicitOne", value: .string("v"), confidence: .explicit, createdAt: Self.now)
        ]
        let ctx = Self.assembler.assemble(domain: "d", preferences: prefs, candidates: [], recentAlerts: [], budget: 10_000, includeDecayed: false)
        guard let exp = ctx.xml.range(of: "explicitOne"), let inf = ctx.xml.range(of: "inferredOne") else {
            Issue.record("missing keys in XML"); return
        }
        #expect(exp.lowerBound < inf.lowerBound)
    }

    @Test func dropsTailWhenOverBudget() {
        let prefs = (0..<10).map { i in
            // First 3 are explicit (high-confidence), rest inferred.
            // Confirm times stagger so explicit ones win the sort tiebreak.
            Pref(
                domain: "d",
                key: "key_\(i)",
                value: .string("value_\(i)"),
                confidence: i < 3 ? .explicit : .inferred,
                createdAt: Self.now,
                lastConfirmedAt: Self.now.addingTimeInterval(TimeInterval(-i))
            )
        }
        // Budget large enough to keep the highest-confidence explicit prefs
        // (key_0, key_1, key_2) but not all 10. Roughly ~75 tokens fits the
        // wrapper + a few prefs.
        let ctx = Self.assembler.assemble(domain: "d", preferences: prefs, candidates: [], recentAlerts: [], budget: 80, includeDecayed: false)
        #expect(!ctx.droppedPreferences.isEmpty)
        let droppedKeys = ctx.droppedPreferences.map(\.key)
        // The top explicit pref must survive.
        #expect(!droppedKeys.contains("key_0"))
        // The lowest-confidence/oldest pref must be among the dropped.
        #expect(droppedKeys.contains("key_9"))
    }

    @Test func escapesSpecialCharactersInPreferenceValues() {
        let prefs = [
            Pref(domain: "d", key: "k", value: .string("a & <b>"), confidence: .explicit, createdAt: Self.now)
        ]
        let ctx = Self.assembler.assemble(domain: "d", preferences: prefs, candidates: [], recentAlerts: [], budget: 10_000, includeDecayed: false)
        #expect(ctx.xml.contains("a &amp; &lt;b&gt;"))
        #expect(!ctx.xml.contains("a & <b>"))
    }

    @Test func escapesSpecialCharactersInCandidateAttributes() {
        let cands = [
            Cand(id: "id&1", type: "t<x>", subject: "s\"q\"", occursAt: Self.now, significance: 0.5, attributes: ["k&": .string("v<>")])
        ]
        let ctx = Self.assembler.assemble(domain: "d", preferences: [], candidates: cands, recentAlerts: [], budget: 10_000, includeDecayed: false)
        #expect(ctx.xml.contains("id=\"id&amp;1\""))
        #expect(ctx.xml.contains("type=\"t&lt;x&gt;\""))
        #expect(ctx.xml.contains("subject=\"s&quot;q&quot;\""))
        #expect(ctx.xml.contains("key=\"k&amp;\""))
        #expect(ctx.xml.contains(">v&lt;&gt;<"))
    }

    @Test func includesOnlyRecentAlertsWithinTheHour() {
        let alerts = [
            Alert(domain: "d", subject: "fresh", type: "t", shownAt: Self.now.addingTimeInterval(-60)),
            Alert(domain: "d", subject: "stale", type: "t", shownAt: Self.now.addingTimeInterval(-7_200))
        ]
        let ctx = Self.assembler.assemble(domain: "d", preferences: [], candidates: [], recentAlerts: alerts, budget: 10_000, includeDecayed: false)
        #expect(ctx.xml.contains("subject=\"fresh\""))
        #expect(!ctx.xml.contains("subject=\"stale\""))
    }

    // MARK: - Snapshots

    @Test func snapshotGolfScenario() {
        let date = Self.now
        let prefs = [
            Pref(domain: "golf.tournament", key: "favouritePlayers", value: .stringList(["rahm", "mcilroy"]), confidence: .explicit, createdAt: date),
            Pref(domain: "golf.tournament", key: "alertAppetite", value: .string("medium"), confidence: .explicit, createdAt: date)
        ]
        let cands = [
            Cand(id: "1", type: "teeingOff", subject: "mcilroy", occursAt: date.addingTimeInterval(480), significance: 0.7, attributes: ["walkingMinutes": .number(6)])
        ]
        let alerts = [
            Alert(domain: "golf.tournament", subject: "rahm", type: "teeingOff", shownAt: date.addingTimeInterval(-480))
        ]
        let ctx = Self.assembler.assemble(domain: "golf.tournament", preferences: prefs, candidates: cands, recentAlerts: alerts, budget: 10_000, includeDecayed: false)
        let expected = """
        <context>
          <preferences>
            <preference domain="golf.tournament" key="favouritePlayers" confidence="explicit">rahm, mcilroy</preference>
            <preference domain="golf.tournament" key="alertAppetite" confidence="explicit">medium</preference>
          </preferences>
          <recent_alerts>
            <alert subject="rahm" type="teeingOff" at="2026-02-02T02:32:00Z"/>
          </recent_alerts>
          <candidates>
            <event id="1" subject="mcilroy" type="teeingOff" significance="0.70" occursAt="2026-02-02T02:48:00Z">
              <attribute key="walkingMinutes" type="number">6.0</attribute>
            </event>
          </candidates>
        </context>
        """
        #expect(ctx.xml == expected)
    }

    @Test func snapshotTennisScenario() {
        let date = Self.now
        let prefs = [
            Pref(domain: "tennis", key: "favouritePlayers", value: .stringList(["alcaraz"]), confidence: .explicit, createdAt: date)
        ]
        let cands = [
            Cand(id: "ev-2", type: "breakPoint", subject: "alcaraz", occursAt: date, significance: 0.85, attributes: ["court": .string("centre"), "setScore": .string("6-5")])
        ]
        let ctx = Self.assembler.assemble(domain: "tennis", preferences: prefs, candidates: cands, recentAlerts: [], budget: 10_000, includeDecayed: false)
        let expected = """
        <context>
          <preferences>
            <preference domain="tennis" key="favouritePlayers" confidence="explicit">alcaraz</preference>
          </preferences>
          <recent_alerts>
          </recent_alerts>
          <candidates>
            <event id="ev-2" subject="alcaraz" type="breakPoint" significance="0.85" occursAt="2026-02-02T02:40:00Z">
              <attribute key="court" type="string">centre</attribute>
              <attribute key="setScore" type="string">6-5</attribute>
            </event>
          </candidates>
        </context>
        """
        #expect(ctx.xml == expected)
    }

    @Test func snapshotEmptyScenario() {
        let ctx = Self.assembler.assemble(domain: "any", preferences: [], candidates: [], recentAlerts: [], budget: 10_000, includeDecayed: false)
        let expected = """
        <context>
          <preferences>
          </preferences>
          <recent_alerts>
          </recent_alerts>
          <candidates>
          </candidates>
        </context>
        """
        #expect(ctx.xml == expected)
    }
}
