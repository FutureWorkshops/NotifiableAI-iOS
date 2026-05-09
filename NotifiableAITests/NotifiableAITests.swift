import Testing
import Foundation
@testable import NotifiableAI

struct NotifiableAITests {
    @Test func pushTokenFormatterProducesLowerHex() {
        let data = Data([0x00, 0x01, 0xab, 0xff])
        #expect(PushTokenFormatter.hex(data) == "0001abff")
    }

    @Test func pushTokenFormatterEmptyData() {
        #expect(PushTokenFormatter.hex(Data()) == "")
    }
}
