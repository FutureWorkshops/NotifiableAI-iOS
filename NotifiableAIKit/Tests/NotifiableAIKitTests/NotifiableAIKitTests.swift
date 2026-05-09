import Testing
import Foundation
@testable import NotifiableAIKit

@Test func missingDeviceWriteKeyThrows() async {
    let client = NotifiableAIClient(baseURL: URL(string: "https://example.test")!)
    await #expect(throws: NotifiableAIError.self) {
        _ = try await client.registerDevice(pushToken: "abc")
    }
}
