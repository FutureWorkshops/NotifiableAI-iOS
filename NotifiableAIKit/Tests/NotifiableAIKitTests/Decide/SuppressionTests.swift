import Testing
import Foundation
@testable import NotifiableAIKit

@Suite struct SuppressionTests {
    typealias Decision = NotifiableDecide.AlertDecision
    typealias Candidate = NotifiableDecide.CandidateEvent
    typealias Store = NotifiableDecide.InMemoryPreferenceStore
    typealias Recorded = NotifiableDecide.RecordedAlert

    @Test func suppressesWhenRecentAlertExistsForSameSubject() async throws {
        let store = Store()
        // Pre-existing alert 30s ago — well inside the 120s suppression window.
        try await store.recordAlert(Recorded(domain: "golf", subject: "rahm", type: "teeingOff", shownAt: Date().addingTimeInterval(-30)))

        let candidate = Candidate(
            id: "ev-1",
            type: "teeingOff",
            subject: "rahm",
            occursAt: Date(),
            significance: 0.7
        )
        let adapter = MockModelAdapter(.alertDecision(
            Decision(shouldAlert: true, candidateId: "ev-1", headline: "Tee off", body: "Rahm is teeing off.", priority: .medium, suppressFor: nil)
        ))
        let engine = NotifiableDecide.Engine(store: store, adapter: adapter)

        let result: Decision = try await engine.decide(
            domain: "golf",
            candidates: [candidate],
            schema: Decision.self
        )

        #expect(result.shouldAlert == false)
        // The original `candidateId` is preserved so the host can still tell why.
        #expect(result.candidateId == "ev-1")
    }

    @Test func recordsAlertWhenNotSuppressed() async throws {
        let store = Store()
        let candidate = Candidate(
            id: "ev-1",
            type: "teeingOff",
            subject: "mcilroy",
            occursAt: Date(),
            significance: 0.9
        )
        let adapter = MockModelAdapter(.alertDecision(
            Decision(shouldAlert: true, candidateId: "ev-1", headline: "Tee off", body: "McIlroy is teeing off.", priority: .high, suppressFor: nil)
        ))
        let engine = NotifiableDecide.Engine(store: store, adapter: adapter)

        let result: Decision = try await engine.decide(
            domain: "golf",
            candidates: [candidate],
            schema: Decision.self
        )

        #expect(result.shouldAlert == true)
        let recent = try await store.recentAlerts(domain: "golf", within: 120)
        #expect(recent.count == 1)
        #expect(recent.first?.subject == "mcilroy")
    }
}
