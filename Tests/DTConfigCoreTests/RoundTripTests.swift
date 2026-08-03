import Testing
@testable import DTConfigCore
import Foundation

@Suite("Round-Trip Tests")
struct RoundTripTests {

    private func fixturesDirectory() -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures").path
    }

    private func loadFixture(_ name: String) throws -> String {
        let path = fixturesDirectory() + "/" + name
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    @Test("Parse and round-trip DT_krea2_robo.json")
    func roundTripKrea2Robo() throws {
        let source = try loadFixture("DT_krea2_robo.json")
        let result = Parser.parse(source)
        #expect(result.description == source)
    }

    @Test("Parse and round-trip DT_krea2_robo_min.json")
    func roundTripKrea2RoboMin() throws {
        let source = try loadFixture("DT_krea2_robo_min.json")
        let result = Parser.parse(source)
        #expect(result.description == source)
    }

    @Test("Parse and round-trip DT_wan2.2_i2v.json")
    func roundTripWan22() throws {
        let source = try loadFixture("DT_wan2.2_i2v.json")
        let result = Parser.parse(source)
        #expect(result.description == source)
    }

    @Test("Parse and round-trip DT_Control_Example.json")
    func roundTripControlExample() throws {
        let source = try loadFixture("DT_Control_Example.json")
        let result = Parser.parse(source)
        #expect(result.description == source)
    }

    @Test("0.80000000000000004 survives round-trip")
    func precisionPreservation() throws {
        let source = try loadFixture("DT_krea2_robo_min.json")
        let result = Parser.parse(source)

        #expect(result.description.contains("0.80000000000000004"),
                "Numeric literal 0.80000000000000004 must survive round-trip")
    }

    @Test("Fixtures parse without errors")
    func fixturesClean() throws {
        let fixtures = ["DT_krea2_robo.json", "DT_krea2_robo_min.json", "DT_wan2.2_i2v.json", "DT_Control_Example.json"]
        for name in fixtures {
            let source = try loadFixture(name)
            let result = Parser.parse(source)
            #expect(result.errors.isEmpty, "Expected no parse errors in \(name), got: \(result.errors)")
        }
    }

    @Test("Simple object value extraction")
    func simpleObjectValue() {
        let result = Parser.parse("{\"a\": 1, \"b\": \"hello\"}")
        let value = result.value
        #expect(value == .object([
            (key: "a", value: .int("1")),
            (key: "b", value: .string("hello"))
        ]))
    }

    @Test("Nested structures")
    func nestedStructures() {
        let result = Parser.parse("{\"arr\": [1, 2, 3], \"obj\": {\"x\": true}}")
        let value = result.value
        #expect(value == .object([
            (key: "arr", value: .array([.int("1"), .int("2"), .int("3")])),
            (key: "obj", value: .object([(key: "x", value: .bool(true))]))
        ]))
    }

    @Test("Numeric literal text preserved in JSONValue")
    func numericLiteralPreserved() {
        let result = Parser.parse("{\"v\": 0.80000000000000004}")
        let value = result.value
        #expect(value == .object([(key: "v", value: .float("0.80000000000000004"))]))
    }

    @Test("All scalar types")
    func allScalars() {
        let result = Parser.parse("[true, false, null, 42, 3.14, \"hi\"]")
        let value = result.value
        #expect(value == .array([
            .bool(true), .bool(false), .null,
            .int("42"), .float("3.14"), .string("hi")
        ]))
    }

    @Test("Empty object and array")
    func emptyContainers() {
        #expect(Parser.parse("{}").value == .object([]))
        #expect(Parser.parse("[]").value == .array([]))
    }

    @Test("String escape decoding")
    func stringEscapes() {
        let result = Parser.parse("[\"hello\\nworld\", \"tab\\there\", \"quote\\\"inside\"]")
        let value = result.value
        #expect(value == .array([
            .string("hello\nworld"),
            .string("tab\there"),
            .string("quote\"inside")
        ]))
    }

    @Test("Bare value round-trip")
    func bareValues() {
        for input in ["42", "\"hello\"", "true", "false", "null", "3.14"] {
            let result = Parser.parse(input)
            #expect(result.description == input)
            #expect(result.errors.isEmpty)
        }
    }

    @Test("Document node wraps everything")
    func documentStructure() {
        let result = Parser.parse("{}")
        #expect(result.root.kind == .document)
        let valueChildren = result.root.children.filter { $0.kind == .value }
        #expect(valueChildren.count == 1)
        #expect(valueChildren[0].children.count == 1)
        #expect(valueChildren[0].children[0].kind == .object)
    }
}
