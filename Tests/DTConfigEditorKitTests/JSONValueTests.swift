import Testing
import Foundation
@testable import DTConfigEditorKit

@Suite("JSONValue parsing")
struct JSONValueTests {

    @Test func parsesNull() throws {
        let value = try JSONValue.parse(from: Data("null".utf8))
        #expect(value == .null)
    }

    @Test func parsesBoolTrue() throws {
        let value = try JSONValue.parse(from: Data("true".utf8))
        #expect(value == .bool(true))
    }

    @Test func parsesBoolFalse() throws {
        let value = try JSONValue.parse(from: Data("false".utf8))
        #expect(value == .bool(false))
    }

    @Test func parsesInt() throws {
        let value = try JSONValue.parse(from: Data("42".utf8))
        #expect(value == .int(42))
    }

    @Test func parsesNegativeInt() throws {
        let value = try JSONValue.parse(from: Data("-7".utf8))
        #expect(value == .int(-7))
    }

    @Test func parsesLargeInt() throws {
        // Seed values from Draw Things can exceed Int32.max
        let value = try JSONValue.parse(from: Data("2980573769".utf8))
        #expect(value == .int(2_980_573_769))
    }

    @Test func parsesDouble() throws {
        let value = try JSONValue.parse(from: Data("3.14".utf8))
        #expect(value == .double(3.14))
    }

    @Test func parsesString() throws {
        let value = try JSONValue.parse(from: Data("\"hello\"".utf8))
        #expect(value == .string("hello"))
    }

    @Test func parsesEmptyArray() throws {
        let value = try JSONValue.parse(from: Data("[]".utf8))
        #expect(value == .array([]))
    }

    @Test func parsesMixedArray() throws {
        let value = try JSONValue.parse(from: Data("[1, \"two\", true, null]".utf8))
        #expect(value == .array([.int(1), .string("two"), .bool(true), .null]))
    }

    @Test func parsesObject() throws {
        let json = """
        {"a": 1, "b": "two", "c": true}
        """
        let value = try JSONValue.parse(from: Data(json.utf8))
        #expect(value == .object(["a": .int(1), "b": .string("two"), "c": .bool(true)]))
    }

    @Test func parsesNestedStructure() throws {
        let json = """
        {"outer": {"inner": [1, 2, 3]}}
        """
        let value = try JSONValue.parse(from: Data(json.utf8))
        #expect(value == .object(["outer": .object(["inner": .array([.int(1), .int(2), .int(3)])])]))
    }

    @Test func distinguishesBoolFromInt() throws {
        let json = """
        {"flag": true, "count": 1}
        """
        let value = try JSONValue.parse(from: Data(json.utf8))
        guard case .object(let dict) = value else {
            Issue.record("Expected object")
            return
        }
        #expect(dict["flag"] == .bool(true))
        #expect(dict["count"] == .int(1))
    }

    @Test func distinguishesBoolFalseFromIntZero() throws {
        let json = """
        {"flag": false, "count": 0}
        """
        let value = try JSONValue.parse(from: Data(json.utf8))
        guard case .object(let dict) = value else {
            Issue.record("Expected object")
            return
        }
        #expect(dict["flag"] == .bool(false))
        #expect(dict["count"] == .int(0))
    }

    @Test func distinguishesIntFromDouble() throws {
        let json = """
        {"integer": 6, "fractional": 6.5}
        """
        let value = try JSONValue.parse(from: Data(json.utf8))
        guard case .object(let dict) = value else {
            Issue.record("Expected object")
            return
        }
        #expect(dict["integer"] == .int(6))
        #expect(dict["fractional"] == .double(6.5))
    }

    @Test func roundTripSerializeAndParse() throws {
        let original = JSONValue.object([
            "string": .string("hello"),
            "int": .int(42),
            "double": .double(3.14),
            "bool": .bool(true),
            "null": .null,
            "array": .array([.int(1), .string("two")]),
            "nested": .object(["key": .bool(false)]),
        ])

        let data = try original.serialized()
        let decoded = try JSONValue.parse(from: data)
        #expect(decoded == original)
    }

    @Test func codableEncodeAndDecode() throws {
        let original = JSONValue.object([
            "name": .string("test"),
            "value": .double(3.14),
            "nested": .array([.int(42), .null]),
        ])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JSONValue.self, from: data)
        #expect(decoded == original)
    }
}
