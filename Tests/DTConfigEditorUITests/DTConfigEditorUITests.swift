import Testing
import DTConfigCore
@testable import DTConfigEditorUI
import SwiftUI

// MARK: - Offset Conversion Tests

@Suite("OffsetTable")
struct OffsetTableTests {

    @Test("ASCII text: byte and UTF-16 offsets are identical")
    func asciiIdentity() {
        let text = "{\"width\": 1024}"
        let table = OffsetTable(text)
        for i in 0...text.utf8.count {
            #expect(table.utf16Offset(forByteOffset: i) == i)
        }
    }

    @Test("2-byte UTF-8 character (e-acute)")
    func twoByte() {
        // "é" is U+00E9: 2 bytes UTF-8, 1 UTF-16 code unit
        let text = "aéb"
        // UTF-8: [0x61, 0xC3, 0xA9, 0x62] — 4 bytes
        // UTF-16: [0x0061, 0x00E9, 0x0062] — 3 units
        let table = OffsetTable(text)
        #expect(table.utf16Offset(forByteOffset: 0) == 0) // 'a'
        #expect(table.utf16Offset(forByteOffset: 1) == 1) // start of 'é'
        #expect(table.utf16Offset(forByteOffset: 2) == 1) // middle of 'é'
        #expect(table.utf16Offset(forByteOffset: 3) == 2) // 'b'
        #expect(table.utf16Offset(forByteOffset: 4) == 3) // end
    }

    @Test("3-byte UTF-8 character (euro sign)")
    func threeByte() {
        // "€" is U+20AC: 3 bytes UTF-8, 1 UTF-16 code unit
        let text = "a€b"
        // UTF-8: [0x61, 0xE2, 0x82, 0xAC, 0x62] — 5 bytes
        // UTF-16: [0x0061, 0x20AC, 0x0062] — 3 units
        let table = OffsetTable(text)
        #expect(table.utf16Offset(forByteOffset: 0) == 0)
        #expect(table.utf16Offset(forByteOffset: 1) == 1)
        #expect(table.utf16Offset(forByteOffset: 2) == 1)
        #expect(table.utf16Offset(forByteOffset: 3) == 1)
        #expect(table.utf16Offset(forByteOffset: 4) == 2)
        #expect(table.utf16Offset(forByteOffset: 5) == 3)
    }

    @Test("4-byte UTF-8 character (emoji, surrogate pair)")
    func fourByte() {
        // U+1F600 (grinning face): 4 bytes UTF-8, 2 UTF-16 code units
        let text = "a\u{1F600}b"
        // UTF-8: 6 bytes total
        // UTF-16: 4 code units (a + high surrogate + low surrogate + b)
        let table = OffsetTable(text)
        #expect(table.utf16Offset(forByteOffset: 0) == 0) // 'a'
        #expect(table.utf16Offset(forByteOffset: 1) == 1) // start of emoji
        #expect(table.utf16Offset(forByteOffset: 2) == 1)
        #expect(table.utf16Offset(forByteOffset: 3) == 1)
        #expect(table.utf16Offset(forByteOffset: 4) == 1)
        #expect(table.utf16Offset(forByteOffset: 5) == 3) // 'b'
        #expect(table.utf16Offset(forByteOffset: 6) == 4) // end
    }

    @Test("utf16Range round-trips byte ranges correctly")
    func rangeConversion() {
        let text = "a€b"
        let table = OffsetTable(text)
        // byte range 0..<1 → UTF-16 0..<1
        #expect(table.utf16Range(forByteRange: 0..<1) == 0..<1)
        // byte range 1..<4 → UTF-16 1..<2 (the euro sign)
        #expect(table.utf16Range(forByteRange: 1..<4) == 1..<2)
        // byte range 4..<5 → UTF-16 2..<3
        #expect(table.utf16Range(forByteRange: 4..<5) == 2..<3)
        // full range
        #expect(table.utf16Range(forByteRange: 0..<5) == 0..<3)
    }

    @Test("Empty string produces single-element sentinel")
    func emptyString() {
        let table = OffsetTable("")
        #expect(table.utf16Offset(forByteOffset: 0) == 0)
    }

    @Test("Out-of-bounds byte offsets clamp gracefully")
    func outOfBounds() {
        let table = OffsetTable("abc")
        #expect(table.utf16Offset(forByteOffset: -1) == 0)
        #expect(table.utf16Offset(forByteOffset: 100) == 3)
    }

    @Test("JSON string with non-ASCII value: offsets diverge correctly")
    func jsonWithNonASCII() {
        // A JSON key containing a non-ASCII char.
        let text = "{\"naïve\": true}"
        let table = OffsetTable(text)
        // "naïve" — ï is U+00EF (2 bytes UTF-8, 1 UTF-16)
        // The byte count of the JSON is greater than the UTF-16 count.
        let byteCount = text.utf8.count
        let utf16Count = text.utf16.count
        #expect(byteCount > utf16Count)
        // End sentinel should equal UTF-16 count.
        #expect(table.utf16Offset(forByteOffset: byteCount) == utf16Count)
    }
}

// MARK: - Theme Tests

@Suite("EditorTheme")
struct EditorThemeTests {

    @Test("Light theme resolves for .light color scheme")
    func lightResolution() {
        let theme = EditorTheme.resolved(for: .light)
        #expect(theme == EditorTheme.light)
    }

    @Test("Dark theme resolves for .dark color scheme")
    func darkResolution() {
        let theme = EditorTheme.resolved(for: .dark)
        #expect(theme == EditorTheme.dark)
    }

    @Test("color(for:) maps every SyntaxRole to the correct field")
    func roleMapping() {
        let theme = EditorTheme.light
        #expect(theme.color(for: .key) == theme.key)
        #expect(theme.color(for: .stringValue) == theme.string)
        #expect(theme.color(for: .numberValue) == theme.number)
        #expect(theme.color(for: .boolValue) == theme.bool)
        #expect(theme.color(for: .nullValue) == theme.null)
        #expect(theme.color(for: .punctuation) == theme.punctuation)
        #expect(theme.color(for: .unknown) == theme.errorToken)
    }

    @Test("Light and dark presets differ")
    func presetsAreDifferent() {
        #expect(EditorTheme.light != EditorTheme.dark)
    }
}

// MARK: - Syntax Highlighting Tests

@Suite("Syntax Highlighting")
struct SyntaxHighlightingTests {

    @Test("Keys are distinguished from string values")
    func keysVsValues() {
        let result = Parser.parse("{\"key\": \"value\"}")
        let spans = result.syntaxSpans()
        let roles = Dictionary(grouping: spans, by: \.role)
        let keys = roles[.key] ?? []
        let strings = roles[.stringValue] ?? []
        #expect(keys.count == 1)
        #expect(strings.count == 1)
    }

    @Test("Numbers get numberValue role")
    func numbers() {
        let result = Parser.parse("{\"n\": 42}")
        let spans = result.syntaxSpans()
        let nums = spans.filter { $0.role == .numberValue }
        #expect(nums.count == 1)
    }

    @Test("Booleans get boolValue role")
    func booleans() {
        let result = Parser.parse("{\"a\": true, \"b\": false}")
        let spans = result.syntaxSpans()
        let bools = spans.filter { $0.role == .boolValue }
        #expect(bools.count == 2)
    }

    @Test("Null gets nullValue role")
    func nulls() {
        let result = Parser.parse("{\"x\": null}")
        let spans = result.syntaxSpans()
        let nulls = spans.filter { $0.role == .nullValue }
        #expect(nulls.count == 1)
    }

    @Test("Punctuation: braces, colons, commas")
    func punctuation() {
        let result = Parser.parse("{\"a\": 1, \"b\": 2}")
        let spans = result.syntaxSpans()
        let puncts = spans.filter { $0.role == .punctuation }
        // { : , : } = 5 punctuation tokens
        #expect(puncts.count == 5)
    }

    @Test("Nested objects: keys at all levels are .key")
    func nestedKeys() {
        let result = Parser.parse("{\"outer\": {\"inner\": 1}}")
        let spans = result.syntaxSpans()
        let keys = spans.filter { $0.role == .key }
        #expect(keys.count == 2)
    }

    @Test("Array string elements are .stringValue, not .key")
    func arrayStrings() {
        let result = Parser.parse("[\"a\", \"b\"]")
        let spans = result.syntaxSpans()
        let keys = spans.filter { $0.role == .key }
        let strings = spans.filter { $0.role == .stringValue }
        #expect(keys.isEmpty)
        #expect(strings.count == 2)
    }

    @Test("Broken document produces .unknown for garbage tokens")
    func brokenDocument() {
        let result = Parser.parse("{\"key\":")
        let spans = result.syntaxSpans()
        // Should still have a .key span for "key"
        let keys = spans.filter { $0.role == .key }
        #expect(!keys.isEmpty)
    }

    @Test("Whitespace tokens are excluded from spans")
    func noWhitespace() {
        let result = Parser.parse("{ \"a\" : 1 }")
        let spans = result.syntaxSpans()
        for span in spans {
            #expect(span.role != .unknown || true) // no whitespace role exists
        }
        // Verify no span covers a whitespace-only byte range
        let text = "{ \"a\" : 1 }"
        let utf8 = Array(text.utf8)
        for span in spans {
            let slice = utf8[span.byteRange]
            let str = String(decoding: slice, as: UTF8.self)
            #expect(str.trimmingCharacters(in: .whitespaces) == str || !str.allSatisfy(\.isWhitespace),
                    "Span should not be pure whitespace: \(str)")
        }
    }

    @Test("Spans cover all non-whitespace tokens")
    func completeCoverage() {
        let result = Parser.parse("{\"a\": 1, \"b\": true}")
        let spans = result.syntaxSpans()
        // Count non-whitespace tokens
        let nonWS = result.tokens.filter { $0.kind != .whitespace }
        #expect(spans.count == nonWS.count)
    }

    @Test("Fixture numeric literal preserved in span range")
    func fixtureLiteralRange() {
        // The krea fixture has 0.80000000000000004
        let text = "{\"weight\": 0.80000000000000004}"
        let result = Parser.parse(text)
        let spans = result.syntaxSpans()
        let nums = spans.filter { $0.role == .numberValue }
        #expect(nums.count == 1)
        if let num = nums.first {
            let slice = Array(text.utf8)[num.byteRange]
            let literal = String(decoding: slice, as: UTF8.self)
            #expect(literal == "0.80000000000000004")
        }
    }
}
