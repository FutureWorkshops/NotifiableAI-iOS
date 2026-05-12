import Testing
import Foundation
@testable import NotifiableAIKit

@Suite struct AlertDecisionValidationTests {
    typealias Decision = NotifiableAIIntelligence.AlertDecision

    @Test func rejectsShouldAlertWithMissingCandidateId() {
        let d = Decision(shouldAlert: true, candidateId: nil, headline: "h", body: "b", priority: .low, suppressFor: nil)
        #expect(throws: NotifiableAIIntelligenceError.self) {
            try d.validate(truncating: { _, _ in })
        }
    }

    @Test func rejectsShouldAlertWithMissingHeadline() {
        let d = Decision(shouldAlert: true, candidateId: "c", headline: nil, body: "b", priority: .low, suppressFor: nil)
        #expect(throws: NotifiableAIIntelligenceError.self) {
            try d.validate(truncating: { _, _ in })
        }
    }

    @Test func rejectsShouldAlertWithMissingBody() {
        let d = Decision(shouldAlert: true, candidateId: "c", headline: "h", body: nil, priority: .low, suppressFor: nil)
        #expect(throws: NotifiableAIIntelligenceError.self) {
            try d.validate(truncating: { _, _ in })
        }
    }

    @Test func truncatesOverLongHeadline() throws {
        let longHeadline = String(repeating: "x", count: 80)
        let d = Decision(shouldAlert: true, candidateId: "c", headline: longHeadline, body: "b", priority: .low, suppressFor: nil)
        let v = try d.validate(truncating: { _, _ in })
        #expect((v.headline ?? "").count == 60)
        #expect((v.headline ?? "").hasSuffix("…"))
    }

    @Test func truncatesOverLongBody() throws {
        let longBody = String(repeating: "y", count: 200)
        let d = Decision(shouldAlert: true, candidateId: "c", headline: "h", body: longBody, priority: .low, suppressFor: nil)
        let v = try d.validate(truncating: { _, _ in })
        #expect((v.body ?? "").count == 120)
        #expect((v.body ?? "").hasSuffix("…"))
    }

    @Test func clampsSuppressForUpper() throws {
        let d = Decision(shouldAlert: false, candidateId: nil, headline: nil, body: nil, priority: .low, suppressFor: 999_999)
        let v = try d.validate(truncating: { _, _ in })
        #expect(v.suppressFor == 86_400)
    }

    @Test func clampsSuppressForLower() throws {
        let d = Decision(shouldAlert: false, candidateId: nil, headline: nil, body: nil, priority: .low, suppressFor: -5)
        let v = try d.validate(truncating: { _, _ in })
        #expect(v.suppressFor == 0)
    }

    @Test func passesValidShouldAlertTrueThrough() throws {
        let d = Decision(shouldAlert: true, candidateId: "c", headline: "h", body: "b", priority: .medium, suppressFor: 60)
        let v = try d.validate(truncating: { _, _ in })
        #expect(v == d)
    }

    @Test func passesValidShouldAlertFalseThrough() throws {
        let d = Decision(shouldAlert: false, candidateId: nil, headline: nil, body: nil, priority: .low, suppressFor: nil)
        let v = try d.validate(truncating: { _, _ in })
        #expect(v == d)
    }
}
