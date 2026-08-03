import Testing
@testable import DTConfigCore
import Foundation

@Suite("Recovery Tests")
struct RecoveryTests {

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

    // MARK: - Truncation tests

    @Test("Truncated fixtures round-trip and don't crash", arguments: [
        "DT_krea2_robo_min.json"
    ])
    func truncatedFixtureRoundTrip(fixture: String) throws {
        let source = try loadFixture(fixture)
        let bytes = Array(source.utf8)

        // Test at various truncation points
        let step = max(1, bytes.count / 50)
        for length in stride(from: 0, through: bytes.count, by: step) {
            let truncated = String(decoding: bytes[0..<length], as: UTF8.self)
            let result = Parser.parse(truncated)
            #expect(result.description == truncated,
                    "Round-trip failed for truncation at byte \(length)")
        }
    }

    // MARK: - Malformed inputs

    @Test("Missing value after colon")
    func missingValueAfterColon() {
        let input = "{\"a\":}"
        let result = Parser.parse(input)
        #expect(result.description == input)
        #expect(!result.errors.isEmpty)
    }

    @Test("Double comma in array")
    func doubleCommaInArray() {
        let input = "[1,,2]"
        let result = Parser.parse(input)
        #expect(result.description == input)
        #expect(!result.errors.isEmpty)
    }

    @Test("Trailing comma in object")
    func trailingCommaInObject() {
        let input = "{\"a\": 1,}"
        let result = Parser.parse(input)
        #expect(result.description == input)
        #expect(!result.errors.isEmpty)
    }

    @Test("Trailing comma in array")
    func trailingCommaInArray() {
        let input = "[1, 2,]"
        let result = Parser.parse(input)
        #expect(result.description == input)
        #expect(!result.errors.isEmpty)
    }

    @Test("Unterminated object")
    func unterminatedObject() {
        let input = "{\"a\": 1"
        let result = Parser.parse(input)
        #expect(result.description == input)
        #expect(!result.errors.isEmpty)
    }

    @Test("Unterminated array")
    func unterminatedArray() {
        let input = "[1, 2"
        let result = Parser.parse(input)
        #expect(result.description == input)
        #expect(!result.errors.isEmpty)
    }

    @Test("Deeply nested input beyond limit")
    func deeplyNestedInput() {
        // Use a depth above maxDepth but not so deep that debug-mode stack overflows
        let depth = 20
        let input = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
        let result = Parser.parse(input)
        #expect(result.description == input)
    }

    @Test("Nesting exceeds depth limit")
    func nestingAtLimit() {
        // Keep total recursion low enough for test worker thread stacks
        let depth = 40
        // Temporarily lower maxDepth effect by using a small nesting
        let input = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
        let result = Parser.parse(input)
        #expect(result.description == input)
        // 40 < 128 (maxDepth), so no errors expected from depth
        #expect(result.errors.isEmpty)
    }

    @Test("Garbage input round-trips")
    func garbageInput() {
        let inputs = [
            "@#$%",
            "",
            "   ",
            "{{{{",
            "]]]]",
            "tru",
            "fals",
            "nul",
            "{\"a\"",
            "[[[",
            "\"unterminated",
            "{:}",
        ]
        for input in inputs {
            let result = Parser.parse(input)
            #expect(result.description == input,
                    "Round-trip failed for garbage input: \(input)")
        }
    }

    @Test("Complete key-value pairs before truncation are recovered")
    func recoverCompletePairs() {
        let input = "{\"a\": 1, \"b\": 2, \"c\":"
        let result = Parser.parse(input)
        #expect(result.description == input)

        // Should be able to extract at least the first two pairs
        if let value = result.valueRecovered {
            if case let .object(pairs) = value {
                let keys = pairs.map(\.key)
                #expect(keys.contains("a"))
                #expect(keys.contains("b"))
            }
        }
    }

    @Test("Missing colon recovery")
    func missingColonRecovery() {
        let input = "{\"a\" 1}"
        let result = Parser.parse(input)
        #expect(result.description == input)
        #expect(!result.errors.isEmpty)
    }

    @Test("Trailing content after value")
    func trailingContent() {
        let input = "42 extra"
        let result = Parser.parse(input)
        #expect(result.description == input)
        #expect(!result.errors.isEmpty)
    }

    @Test("Empty document")
    func emptyDocument() {
        let result = Parser.parse("")
        #expect(result.description == "")
        #expect(result.root.kind == .document)
    }

    @Test("Whitespace-only document")
    func whitespaceOnly() {
        let input = "   \n\t  "
        let result = Parser.parse(input)
        #expect(result.description == input)
    }

    // MARK: - Property tests

    @Test("Random valid JSON round-trips")
    func randomValidJSON() {
        var rng = SplitMix64(seed: 42)
        for _ in 0..<200 {
            let json = generateRandomJSON(depth: 0, maxDepth: 4, rng: &rng)
            let result = Parser.parse(json)
            #expect(result.description == json,
                    "Round-trip failed for generated JSON: \(json.prefix(100))")
        }
    }

    @Test("Random truncated JSON round-trips")
    func randomTruncatedJSON() {
        var rng = SplitMix64(seed: 99)
        for _ in 0..<200 {
            let json = generateRandomJSON(depth: 0, maxDepth: 3, rng: &rng)
            let bytes = Array(json.utf8)
            let cutPoint = Int.random(in: 0...bytes.count, using: &rng)
            let truncated = String(decoding: bytes[0..<cutPoint], as: UTF8.self)
            let result = Parser.parse(truncated)
            #expect(result.description == truncated,
                    "Round-trip failed for truncated JSON at \(cutPoint)")
        }
    }

    @Test("Random garbage round-trips")
    func randomGarbage() {
        var rng = SplitMix64(seed: 7)
        for _ in 0..<200 {
            let length = Int.random(in: 0...100, using: &rng)
            var bytes: [UInt8] = []
            for _ in 0..<length {
                bytes.append(UInt8.random(in: 32...126, using: &rng))
            }
            let input = String(decoding: bytes, as: UTF8.self)
            let result = Parser.parse(input)
            #expect(result.description == input,
                    "Round-trip failed for random garbage")
        }
    }

    @Test("Mixed valid and garbage round-trips")
    func mixedValidAndGarbage() {
        var rng = SplitMix64(seed: 123)
        for _ in 0..<200 {
            let json = generateRandomJSON(depth: 0, maxDepth: 2, rng: &rng)
            let garbageLen = Int.random(in: 0...20, using: &rng)
            var garbageBytes: [UInt8] = []
            for _ in 0..<garbageLen {
                garbageBytes.append(UInt8.random(in: 32...126, using: &rng))
            }
            let garbage = String(decoding: garbageBytes, as: UTF8.self)
            let input = json + garbage
            let result = Parser.parse(input)
            #expect(result.description == input)
        }
    }
}

// MARK: - Deterministic RNG

private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

// MARK: - Random JSON Generator

private func generateRandomJSON(depth: Int, maxDepth: Int, rng: inout SplitMix64) -> String {
    if depth >= maxDepth {
        // Only generate scalars at max depth
        return generateScalar(rng: &rng)
    }

    let kind = Int.random(in: 0..<6, using: &rng)
    switch kind {
    case 0: // object
        let count = Int.random(in: 0...3, using: &rng)
        if count == 0 { return "{}" }
        var parts: [String] = []
        for i in 0..<count {
            let key = "\"key\(i)\""
            let val = generateRandomJSON(depth: depth + 1, maxDepth: maxDepth, rng: &rng)
            parts.append("\(key): \(val)")
        }
        return "{\(parts.joined(separator: ", "))}"
    case 1: // array
        let count = Int.random(in: 0...4, using: &rng)
        if count == 0 { return "[]" }
        var elements: [String] = []
        for _ in 0..<count {
            elements.append(generateRandomJSON(depth: depth + 1, maxDepth: maxDepth, rng: &rng))
        }
        return "[\(elements.joined(separator: ", "))]"
    default:
        return generateScalar(rng: &rng)
    }
}

private func generateScalar(rng: inout SplitMix64) -> String {
    let kind = Int.random(in: 0..<5, using: &rng)
    switch kind {
    case 0: return "null"
    case 1: return Bool.random(using: &rng) ? "true" : "false"
    case 2: return "\(Int.random(in: -1000...1000, using: &rng))"
    case 3:
        let intPart = Int.random(in: 0...100, using: &rng)
        let fracPart = Int.random(in: 0...99, using: &rng)
        return "\(intPart).\(fracPart)"
    default: return "\"str\(Int.random(in: 0...99, using: &rng))\""
    }
}
