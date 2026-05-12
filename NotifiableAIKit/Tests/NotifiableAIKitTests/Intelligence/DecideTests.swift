import Testing
import Foundation
@testable import NotifiableAIKit

@Suite struct DecideTests {
    typealias Decision = NotifiableIntelligence.AlertDecision
    typealias Candidate = NotifiableIntelligence.CandidateEvent
    typealias Store = NotifiableIntelligence.InMemoryPreferenceStore

    @Test func contextBlockContainsCandidateId() async throws {
        let store = Store()
        let candidate = Candidate(id: "ev-42", type: "teeingOff", subject: "rahm", occursAt: Date(), significance: 0.5)
        let adapter = MockModelAdapter(.alertDecision(
            Decision(shouldAlert: false, candidateId: nil, headline: nil, body: nil, priority: .low, suppressFor: nil)
        ))
        let engine = NotifiableIntelligence.Engine(store: store, adapter: adapter)
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
        let engine = NotifiableIntelligence.Engine(store: store, adapter: adapter)
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
        let engine = NotifiableIntelligence.Engine(store: store, adapter: adapter)
        await #expect(throws: NotifiableIntelligenceError.self) {
            _ = try await engine.decide(domain: "golf", candidates: [candidate], schema: Decision.self)
        }
    }

    @Test func propagatesFoundationModelUnavailable() async throws {
        let store = Store()
        let adapter = MockModelAdapter(.error(NotifiableIntelligenceError.foundationModelUnavailable))
        let engine = NotifiableIntelligence.Engine(store: store, adapter: adapter)
        await #expect(throws: NotifiableIntelligenceError.self) {
            _ = try await engine.decide(domain: "golf", candidates: [], schema: Decision.self)
        }
    }

    @Test func includesAlertDecisionShapeHintInContext() async throws {
        let store = Store()
        let candidate = Candidate(id: "ev-1", type: "t", subject: "s", occursAt: Date(), significance: 0.5)
        let adapter = MockModelAdapter(.alertDecision(
            Decision(shouldAlert: false, candidateId: nil, headline: nil, body: nil, priority: .low, suppressFor: nil)
        ))
        let engine = NotifiableIntelligence.Engine(store: store, adapter: adapter)
        _ = try await engine.decide(domain: "d", candidates: [candidate], schema: Decision.self)
        let context = (await adapter.capturedContextBlock) ?? ""
        #expect(context.contains("<response_shape>"))
        #expect(context.contains("shouldAlert"))
        #expect(context.contains("priority"))
    }

    @Test func decoderTolerantOfPreambleAndCodeFences() throws {
        let prosey = """
        Sure, here's the decision:
        ```json
        {"shouldAlert": false, "candidateId": null, "headline": null, "body": null, "priority": "low", "suppressFor": null}
        ```
        Let me know if you need adjustments.
        """
        let decoded: Decision = try NotifiableIntelligence.FoundationModelAdapter.decodeJSON(prosey, as: Decision.self)
        #expect(decoded.shouldAlert == false)
        #expect(decoded.priority == .low)
    }
}
