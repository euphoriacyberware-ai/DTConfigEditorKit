import Testing
@testable import DTConfigCore
import Foundation

@Suite("Byte Range Tests")
struct ByteRangeTests {

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

    @Test("Token byte ranges slice to correct text")
    func tokenByteRanges() {
        let input = "{\"key\": [1, true, null]}"
        let bytes = Array(input.utf8)
        let tokens = Lexer.tokenize(input)

        for token in tokens {
            let sliced = String(decoding: bytes[token.range], as: UTF8.self)
            #expect(sliced == token.text,
                    "Token '\(token.text)' byte range should slice to same text")
        }
    }

    @Test("Member key byte ranges point to quoted key strings")
    func memberKeyRanges() {
        let input = "{\"alpha\": 1, \"beta\": 2, \"gamma\": 3}"
        let result = Parser.parse(input)
        let bytes = Array(input.utf8)

        let obj = result.root.children.first(where: { $0.kind == .value })?.children.first
        #expect(obj?.kind == .object)

        let expectedKeys = ["\"alpha\"", "\"beta\"", "\"gamma\""]
        let members = obj!.children.filter { $0.kind == .member }
        #expect(members.count == 3)

        for (member, expectedKey) in zip(members, expectedKeys) {
            let keyNode = member.children[0]
            let keyText = String(decoding: bytes[keyNode.byteRange], as: UTF8.self).trimmingCharacters(in: .whitespaces)
            // The key node's byte range should contain the quoted key string
            #expect(keyText.contains(expectedKey.dropFirst().dropLast()),
                    "Key node should contain key text: expected \(expectedKey), got \(keyText)")
        }
    }

    @Test("CSTNode byte ranges cover full source for fixtures", arguments: [
        "DT_krea2_robo.json",
        "DT_krea2_robo_min.json",
        "DT_wan2.2_i2v.json",
        "DT_Control_Example.json"
    ])
    func fixtureByteRangeCoverage(fixture: String) throws {
        let source = try loadFixture(fixture)
        let result = Parser.parse(source)

        // Document should span entire source
        #expect(result.root.byteRange.lowerBound == 0)
        #expect(result.root.byteRange.upperBound == source.utf8.count,
                "Document byte range should cover entire source in \(fixture)")
    }

    @Test("All member key byte ranges in fixtures slice to quoted strings", arguments: [
        "DT_krea2_robo.json",
        "DT_krea2_robo_min.json",
        "DT_wan2.2_i2v.json",
        "DT_Control_Example.json"
    ])
    func fixtureKeyByteRanges(fixture: String) throws {
        let source = try loadFixture(fixture)
        let result = Parser.parse(source)
        let bytes = Array(source.utf8)

        func walkMembers(_ node: CSTNode) {
            if node.kind == .member && !node.children.isEmpty {
                let keyNode = node.children[0]
                // Find the string token in this key node
                for i in keyNode.tokenRange {
                    let token = result.tokens[i]
                    if token.kind == .string {
                        let sliced = String(decoding: bytes[token.range], as: UTF8.self)
                        #expect(sliced.hasPrefix("\"") && sliced.hasSuffix("\""),
                                "Key token should be a quoted string, got: \(sliced)")
                    }
                }
            }
            for child in node.children {
                walkMembers(child)
            }
        }

        walkMembers(result.root)
    }
}
