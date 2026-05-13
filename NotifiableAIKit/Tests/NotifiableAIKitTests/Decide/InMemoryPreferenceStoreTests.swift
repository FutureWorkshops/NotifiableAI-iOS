import Testing
import Foundation
@testable import NotifiableAIKit

@Suite struct InMemoryPreferenceStoreTests {
    typealias Store = NotifiableDecide.InMemoryPreferenceStore
    typealias Preference = NotifiableDecide.Preference
    typealias RecordedAlert = NotifiableDecide.RecordedAlert

    @Test func setAndGetRoundTrip() async throws {
        let store = Store()
        let pref = Preference(
            domain: "golf",
            key: "favouritePlayers",
            value: .stringList(["rahm", "mcilroy"]),
            confidence: .explicit,
            createdAt: Date()
        )
        try await store.set(pref)
        let fetched = try await store.get(domain: "golf", key: "favouritePlayers")
        #expect(fetched == pref)
    }

    @Test func allFiltersByDomain() async throws {
        let store = Store()
        try await store.set(Preference(domain: "golf", key: "a", value: .string("x"), confidence: .explicit, createdAt: Date()))
        try await store.set(Preference(domain: "tennis", key: "a", value: .string("y"), confidence: .explicit, createdAt: Date()))
        let golf = try await store.all(domain: "golf")
        #expect(golf.count == 1)
        #expect(golf.first?.value == .string("x"))
    }

    @Test func recentAlertsHonoursWindow() async throws {
        let store = Store()
        let now = Date()
        try await store.recordAlert(RecordedAlert(domain: "golf", subject: "rahm", type: "teeingOff", shownAt: now.addingTimeInterval(-30)))
        try await store.recordAlert(RecordedAlert(domain: "golf", subject: "rahm", type: "teeingOff", shownAt: now.addingTimeInterval(-10_000)))
        let recent = try await store.recentAlerts(domain: "golf", within: 60)
        #expect(recent.count == 1)
    }
}
