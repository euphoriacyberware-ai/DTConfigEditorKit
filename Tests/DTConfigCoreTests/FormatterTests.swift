import Testing
@testable import DTConfigCore

@Suite("JSONFormatter")
struct FormatterTests {

    // MARK: - Format

    @Test("Format minimal fixture preserves JSONValue")
    func formatPreservesValue() {
        let source = """
        {"shift":3,"width":1024,"loras":[{"mode":"all","file":"test.ckpt","weight":0.80000000000000004}]}
        """
        let formatted = JSONFormatter.format(source)
        let originalValue = Parser.parse(source).value
        let formattedValue = Parser.parse(formatted).value
        #expect(originalValue == formattedValue)
        #expect(originalValue != nil)
    }

    @Test("Format is idempotent")
    func formatIdempotent() {
        let source = """
        {"a":1,"b":{"c":true},"d":[1,2,3]}
        """
        let once = JSONFormatter.format(source)
        let twice = JSONFormatter.format(once)
        #expect(once == twice)
    }

    @Test("Format already-pretty input is idempotent")
    func formatPrettyIdempotent() {
        let source = """
        {
          "a": 1,
          "b": true
        }
        """
        let formatted = JSONFormatter.format(source)
        #expect(formatted == source)
    }

    @Test("Format empty object")
    func formatEmptyObject() {
        #expect(JSONFormatter.format("{}") == "{}")
    }

    @Test("Format empty array")
    func formatEmptyArray() {
        #expect(JSONFormatter.format("[]") == "[]")
    }

    @Test("Format nested objects and arrays")
    func formatNested() {
        let source = """
        {"a":{"b":[1,2]},"c":[]}
        """
        let expected = """
        {
          "a": {
            "b": [
              1,
              2
            ]
          },
          "c": []
        }
        """
        #expect(JSONFormatter.format(source) == expected)
    }

    @Test("Numeric literal 0.80000000000000004 preserved")
    func numericLiteralPreserved() {
        let source = "{\"weight\":0.80000000000000004}"
        let formatted = JSONFormatter.format(source)
        #expect(formatted.contains("0.80000000000000004"))
    }

    @Test("Format preserves string escapes")
    func stringEscapes() {
        let source = "{\"key\":\"line1\\nline2\"}"
        let formatted = JSONFormatter.format(source)
        #expect(formatted.contains("\"line1\\nline2\""))
    }

    @Test("Format scalar values")
    func formatScalar() {
        #expect(JSONFormatter.format("42") == "42")
        #expect(JSONFormatter.format("true") == "true")
        #expect(JSONFormatter.format("null") == "null")
        #expect(JSONFormatter.format("\"hello\"") == "\"hello\"")
    }

    // MARK: - Sort keys

    @Test("Sort keys alphabetically")
    func sortKeysBasic() {
        let source = "{\"c\":3,\"a\":1,\"b\":2}"
        let sorted = JSONFormatter.sortKeys(source)
        let result = Parser.parse(sorted)
        guard case .object(let pairs) = result.value else {
            Issue.record("Expected object")
            return
        }
        #expect(pairs.map(\.key) == ["a", "b", "c"])
    }

    @Test("Sort keys is idempotent")
    func sortKeysIdempotent() {
        let source = "{\"c\":3,\"a\":1,\"b\":2}"
        let once = JSONFormatter.sortKeys(source)
        let twice = JSONFormatter.sortKeys(once)
        #expect(once == twice)
    }

    @Test("Sort keys recurses into nested objects")
    func sortKeysNested() {
        let source = "{\"z\":{\"b\":2,\"a\":1},\"y\":true}"
        let sorted = JSONFormatter.sortKeys(source)
        let result = Parser.parse(sorted)
        guard case .object(let outer) = result.value else {
            Issue.record("Expected object")
            return
        }
        #expect(outer[0].key == "y")
        #expect(outer[1].key == "z")
        if case .object(let inner) = outer[1].value {
            #expect(inner[0].key == "a")
            #expect(inner[1].key == "b")
        } else {
            Issue.record("Expected nested object")
        }
    }

    @Test("Sort then format equals format then sort")
    func sortFormatCommutativity() {
        let source = "{\"c\":3,\"a\":{\"z\":1,\"y\":2},\"b\":[1]}"
        let sf = JSONFormatter.format(JSONFormatter.sortKeys(source))
        let fs = JSONFormatter.sortKeys(JSONFormatter.format(source))
        // Both should produce the same JSONValue.
        let sfValue = Parser.parse(sf).value
        let fsValue = Parser.parse(fs).value
        #expect(sfValue == fsValue)
        #expect(sfValue != nil)
    }

    @Test("Sort preserves unknown keys")
    func sortPreservesUnknownKeys() {
        let source = "{\"known\":1,\"futureFeature\":true,\"anotherKnown\":2}"
        let sorted = JSONFormatter.sortKeys(source)
        let result = Parser.parse(sorted)
        guard case .object(let pairs) = result.value else {
            Issue.record("Expected object")
            return
        }
        let keys = pairs.map(\.key)
        #expect(keys.contains("futureFeature"))
        #expect(keys == keys.sorted())
    }

    @Test("Sort preserves separators (whitespace style)")
    func sortPreservesSeparators() {
        let source = "{ \"b\" : 2 , \"a\" : 1 }"
        let sorted = JSONFormatter.sortKeys(source)
        // The separators between members should be preserved.
        #expect(sorted.contains(" , "))
    }

    // MARK: - Cursor helpers

    @Test("keyAtOffset finds correct key")
    func keyAtOffset() {
        let source = "{\"alpha\":1,\"beta\":2}"
        // "beta" key token starts at byte 11 (after {"alpha":1,)
        // Value 2 is at byte 18
        let key = JSONFormatter.keyAtOffset(18, in: source)
        #expect(key == "beta")
    }

    @Test("keyAtOffset returns nil outside members")
    func keyAtOffsetOutside() {
        let source = "[1, 2, 3]"
        #expect(JSONFormatter.keyAtOffset(2, in: source) == nil)
    }

    @Test("offsetOfKey finds correct offset")
    func offsetOfKey() {
        let source = "{\"alpha\":1,\"beta\":2}"
        let offset = JSONFormatter.offsetOfKey("beta", in: source)
        #expect(offset != nil)
        if let offset {
            let bytes = Array(source.utf8)
            #expect(bytes[offset] == UInt8(ascii: "\""))
            let slice = String(decoding: bytes[offset..<offset+6], as: UTF8.self)
            #expect(slice == "\"beta\"")
        }
    }

    @Test("offsetOfKey returns nil for missing key")
    func offsetOfKeyMissing() {
        let source = "{\"alpha\":1}"
        #expect(JSONFormatter.offsetOfKey("beta", in: source) == nil)
    }

    @Test("keyAtOffset and offsetOfKey round-trip")
    func cursorRoundTrip() {
        let source = "{\"first\":1,\"second\":{\"inner\":true},\"third\":3}"
        let target = "second"
        guard let offset = JSONFormatter.offsetOfKey(target, in: source) else {
            Issue.record("Key not found")
            return
        }
        let recovered = JSONFormatter.keyAtOffset(offset, in: source)
        #expect(recovered == target)
    }
}
