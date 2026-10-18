import Testing
@testable import DTConfigCore

@Suite("JSONString")
struct JSONStringTests {
    @Test("Decodes escapes, including surrogate pairs")
    func decodeEscapes() {
        #expect(JSONString.decode(#""a\"b\\c\n""#) == "a\"b\\c\n")
        #expect(JSONString.decode(#""é""#) == "é")
        #expect(JSONString.decode(#""😀""#) == "😀")
        #expect(JSONString.decode(#""\ud83d""#) == "\u{FFFD}")
    }

    @Test("Tolerates unterminated literals")
    func unterminated() {
        #expect(JSONString.decode(#""abc"#) == "abc")
        #expect(JSONString.decode(#""abc\""#) == "abc\"")
        #expect(JSONString.decode(#""abc\\""#) == "abc\\")
    }

    @Test("quote round-trips through decode")
    func quoteRoundTrip() {
        for value in ["plain", "a\"b", "back\\slash", "tab\tnew\nline", "\u{01}ctl", "é😀"] {
            #expect(JSONString.decode(JSONString.quote(value)) == value)
        }
    }
}
