import Testing
import Foundation
@testable import NotifiableAIKit

@Suite struct XMLEscapingTests {
    @Test func escapesAmpersand() {
        #expect(XMLEscaper.escape("A & B") == "A &amp; B")
    }

    @Test func escapesLessAndGreater() {
        #expect(XMLEscaper.escape("<tag>") == "&lt;tag&gt;")
    }

    @Test func escapesQuotes() {
        #expect(XMLEscaper.escape("\"x\" 'y'") == "&quot;x&quot; &apos;y&apos;")
    }

    @Test func roundTripsAllFiveSpecials() {
        let input = "&<>\"'"
        #expect(XMLEscaper.escape(input) == "&amp;&lt;&gt;&quot;&apos;")
    }

    @Test func stripsControlCharacters() {
        let input = "a\u{01}b\u{08}c"
        #expect(XMLEscaper.escape(input) == "abc")
    }

    @Test func preservesAllowedWhitespace() {
        let input = "tab\there\nnewline\rcr"
        #expect(XMLEscaper.escape(input) == "tab\there\nnewline\rcr")
    }
}
