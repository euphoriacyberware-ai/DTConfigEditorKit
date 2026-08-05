import Testing
@testable import DTConfigCore

@Suite("Lexer Tests")
struct LexerTests {
    @Test("Empty input produces no tokens")
    func emptyInput() {
        let tokens = Lexer.tokenize("")
        #expect(tokens.isEmpty)
    }

    @Test("Single braces and brackets")
    func structuralTokens() {
        let tokens = Lexer.tokenize("{}")
        #expect(tokens.count == 2)
        #expect(tokens[0].kind == .leftBrace)
        #expect(tokens[1].kind == .rightBrace)
    }

    @Test("All structural tokens")
    func allStructural() {
        let tokens = Lexer.tokenize("{}[]:,")
        let kinds: [TokenKind] = [.leftBrace, .rightBrace, .leftBracket, .rightBracket, .colon, .comma]
        #expect(tokens.count == kinds.count)
        for (token, kind) in zip(tokens, kinds) {
            #expect(token.kind == kind)
        }
    }

    @Test("Simple string")
    func simpleString() {
        let tokens = Lexer.tokenize("\"hello\"")
        #expect(tokens.count == 1)
        #expect(tokens[0].kind == .string)
        #expect(tokens[0].text == "\"hello\"")
    }

    @Test("String with escapes")
    func stringWithEscapes() {
        let input = "\"he\\\"llo\\n\""
        let tokens = Lexer.tokenize(input)
        #expect(tokens.count == 1)
        #expect(tokens[0].kind == .string)
        #expect(tokens[0].text == input)
    }

    @Test("Unterminated string")
    func unterminatedString() {
        let tokens = Lexer.tokenize("\"hello")
        #expect(tokens.count == 1)
        #expect(tokens[0].kind == .string)
        #expect(tokens[0].text == "\"hello")
    }

    @Test("Integer number")
    func intNumber() {
        let tokens = Lexer.tokenize("42")
        #expect(tokens.count == 1)
        #expect(tokens[0].kind == .number)
        #expect(tokens[0].text == "42")
    }

    @Test("Negative number")
    func negativeNumber() {
        let tokens = Lexer.tokenize("-1")
        #expect(tokens.count == 1)
        #expect(tokens[0].kind == .number)
        #expect(tokens[0].text == "-1")
    }

    @Test("Float number preserves full precision")
    func floatPrecision() {
        let input = "0.80000000000000004"
        let tokens = Lexer.tokenize(input)
        #expect(tokens.count == 1)
        #expect(tokens[0].kind == .number)
        #expect(tokens[0].text == input)
    }

    @Test("Scientific notation")
    func scientificNotation() {
        let tokens = Lexer.tokenize("1.5e10")
        #expect(tokens.count == 1)
        #expect(tokens[0].kind == .number)
        #expect(tokens[0].text == "1.5e10")
    }

    @Test("Keywords: true, false, null")
    func keywords() {
        let tokens = Lexer.tokenize("true false null")
        let nonWS = tokens.filter { $0.kind != .whitespace }
        #expect(nonWS.count == 3)
        #expect(nonWS[0].kind == .true)
        #expect(nonWS[1].kind == .false)
        #expect(nonWS[2].kind == .null)
    }

    @Test("Partial keyword becomes unknown")
    func partialKeyword() {
        let tokens = Lexer.tokenize("tru")
        #expect(tokens[0].kind == .unknown)
        #expect(tokens[0].text == "t")
    }

    @Test("Whitespace runs are single tokens")
    func whitespaceRuns() {
        let tokens = Lexer.tokenize("  \t\n  ")
        #expect(tokens.count == 1)
        #expect(tokens[0].kind == .whitespace)
    }

    @Test("Unknown bytes")
    func unknownBytes() {
        let tokens = Lexer.tokenize("@")
        #expect(tokens.count == 1)
        #expect(tokens[0].kind == .unknown)
        #expect(tokens[0].text == "@")
    }

    @Test("Tokens partition the source exactly")
    func contiguousRanges() {
        let input = "{\"key\": [1, true, null]}"
        let tokens = Lexer.tokenize(input)

        #expect(tokens.first!.range.lowerBound == 0)
        #expect(tokens.last!.range.upperBound == input.utf8.count)

        for i in 1..<tokens.count {
            #expect(tokens[i].range.lowerBound == tokens[i - 1].range.upperBound,
                    "Gap between token \(i - 1) and \(i)")
        }
    }

    @Test("Round-trip: concatenated token texts equal source")
    func roundTrip() {
        let input = "{ \"a\" : 1, \"b\": [true, false, null, 0.80000000000000004] }"
        let tokens = Lexer.tokenize(input)
        let reconstructed = tokens.map(\.text).joined()
        #expect(reconstructed == input)
    }

    @Test("Zero number")
    func zeroNumber() {
        let tokens = Lexer.tokenize("0")
        #expect(tokens.count == 1)
        #expect(tokens[0].kind == .number)
        #expect(tokens[0].text == "0")
    }

    @Test("Negative float")
    func negativeFloat() {
        let tokens = Lexer.tokenize("-3.14")
        #expect(tokens.count == 1)
        #expect(tokens[0].kind == .number)
        #expect(tokens[0].text == "-3.14")
    }
}
