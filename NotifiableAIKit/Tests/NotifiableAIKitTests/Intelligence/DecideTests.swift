import Testing
import Foundation
@testable import NotifiableAIKit

@Suite struct DecideTests {
    typealias Decision = NotifiableAIIntelligence.AlertDecision
    typealias Candidate = NotifiableAIIntelligence.CandidateEvent
    typealias Store = NotifiableAIIntelligence.InMemoryPreferenceStore

    @Test func contextBlockContainsCandidateId() async throws {
        let store = Store()
        let candidate = Candidate(id: "ev-42", type: "teeingOff", subject: "rahm", occursAt: Date(), significance: 0.5)
        let adapter = MockModelAdapter(.alertDecision(
            Decision(shouldAlert: false, candidateId: nil, headline: nil, body: nil, priority: .low, suppressFor: nil)
        ))
        let engine = NotifiableAIIntelligence.Engine(store: store, adapter: adapter)
        _ = try await engine.decide(domain: "golf", candidates: [candidate], schema: Decision.self)
        let context = (await adapter.capturedContextBlock) ?? ""
        #expect(context.contains("ev-42"))
        #expect(context.contains("teeingOff"))
    }

    @Test func recordsAlertOnPositiveDecision() async throws {
        let store = Store()
        let candidate = Candidate(id: "ev-1", type: "eagle", subject: "rahm", occursAt: Date(), significance: 0.9)
        let adapter = MockModelAdapter(.alertDecision(
            Decision(shouldAlert: true, candidateId: "ev-1", headline: "h", body: "b", priority: .high, suppressFor: nil)
        ))
        let engine = NotifiableAIIntelligence.Engine(store: store, adapter: adapter)
        _ = try await engine.decide(domain: "golf", candidates: [candidate], schema: Decision.self)
        let recent = try await store.recentAlerts(domain: "golf", within: 120)
        #expect(recent.count == 1)
    }

    @Test func throwsDecisionValidationFailedOnSchemaViolatingResponse() async throws {
        // shouldAlert=true but missing candidateId, headline, body → engine
        // rejects after decoding.
        let store = Store()
        let candidate = Candidate(id: "ev-1", type: "eagle", subject: "rahm", occursAt: Date(), significance: 0.5)
        let adapter = MockModelAdapter(.alertDecision(
            Decision(shouldAlert: true, candidateId: nil, headline: nil, body: nil, priority: .low, suppressFor: nil)
        ))
        let engine = NotifiableAIIntelligence.Engine(store: store, adapter: adapter)
        await #expect(throws: NotifiableAIIntelligenceError.self) {
            _ = try await engine.decide(domain: "golf", candidates: [candidate], schema: Decision.self)
        }
    }

    @Test func propagatesFoundationModelUnavailable() async throws {
        let store = Store()
        let adapter = MockModelAdapter(.error(NotifiableAIIntelligenceError.foundationModelUnavailable))
        let engine = NotifiableAIIntelligence.Engine(store: store, adapter: adapter)
        await #expect(throws: NotifiableAIIntelligenceError.self) {
            _ = try await engine.decide(domain: "golf", candidates: [], schema: Decision.self)
        }
    }
}
