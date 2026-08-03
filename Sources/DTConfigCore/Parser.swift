public struct ParseResult: Sendable {
    public let source: String
    public let tokens: [Token]
    public let root: CSTNode
    public let errors: [ParseError]

    public var description: String {
        tokens.map(\.text).joined()
    }

    public var value: JSONValue? {
        guard errors.isEmpty else { return nil }
        return extractValue(from: root)
    }

    public var valueRecovered: JSONValue? {
        extractValue(from: root)
    }

    private func extractValue(from node: CSTNode) -> JSONValue? {
        switch node.kind {
        case .document:
            for child in node.children {
                if let v = extractValue(from: child) {
                    return v
                }
            }
            return nil
        case .value:
            if !node.children.isEmpty {
                return extractValue(from: node.children[0])
            }
            // leaf value — find the significant token
            for i in node.tokenRange {
                let token = tokens[i]
                switch token.kind {
                case .string:
                    return .string(decodeStringLiteral(token.text))
                case .number:
                    if token.text.contains(".") || token.text.contains("e") || token.text.contains("E") {
                        return .float(token.text)
                    } else {
                        return .int(token.text)
                    }
                case .true:
                    return .bool(true)
                case .false:
                    return .bool(false)
                case .null:
                    return .null
                default:
                    continue
                }
            }
            return nil
        case .object:
            var pairs: [(key: String, value: JSONValue)] = []
            for child in node.children {
                if child.kind == .member, child.children.count >= 2 {
                    if let key = extractStringKey(from: child.children[0]),
                       let val = extractValue(from: child.children[1]) {
                        pairs.append((key: key, value: val))
                    }
                }
            }
            return .object(pairs)
        case .array:
            var elements: [JSONValue] = []
            for child in node.children {
                if let v = extractValue(from: child) {
                    elements.append(v)
                }
            }
            return .array(elements)
        case .member, .error:
            return nil
        }
    }

    private func extractStringKey(from node: CSTNode) -> String? {
        for i in node.tokenRange {
            let token = tokens[i]
            if token.kind == .string {
                return decodeStringLiteral(token.text)
            }
        }
        return nil
    }

    private func decodeStringLiteral(_ raw: String) -> String {
        // Strip quotes
        guard raw.count >= 2, raw.hasPrefix("\"") else { return raw }
        let inner: Substring
        if raw.hasSuffix("\"") {
            inner = raw.dropFirst().dropLast()
        } else {
            inner = raw.dropFirst() // unterminated
        }
        guard inner.contains("\\") else { return String(inner) }

        var result = ""
        var it = inner.makeIterator()
        while let ch = it.next() {
            if ch == "\\" {
                guard let esc = it.next() else {
                    result.append("\\")
                    break
                }
                switch esc {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/": result.append("/")
                case "b": result.append("\u{08}")
                case "f": result.append("\u{0C}")
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                case "u":
                    var hex = ""
                    for _ in 0..<4 {
                        guard let h = it.next() else { break }
                        hex.append(h)
                    }
                    if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                        result.append(Character(scalar))
                    } else {
                        result.append("\\u")
                        result.append(hex)
                    }
                default:
                    result.append("\\")
                    result.append(esc)
                }
            } else {
                result.append(ch)
            }
        }
        return result
    }
}

public enum Parser {
    public static let maxDepth = 128

    public static func parse(_ source: String) -> ParseResult {
        let tokens = Lexer.tokenize(source)
        var state = ParserState(tokens: tokens, source: source)
        let root = state.parseDocument()
        return ParseResult(source: source, tokens: tokens, root: root, errors: state.errors)
    }
}

private struct ParserState {
    let tokens: [Token]
    let source: String
    var pos: Int = 0
    var errors: [ParseError] = []
    var depth: Int = 0

    var atEnd: Bool { pos >= tokens.count }

    func peek() -> Token? {
        guard pos < tokens.count else { return nil }
        return tokens[pos]
    }

    func peekKind() -> TokenKind? {
        peek()?.kind
    }

    mutating func advance() -> Token {
        let t = tokens[pos]
        pos += 1
        return t
    }

    mutating func skipWhitespace() {
        while pos < tokens.count && tokens[pos].kind == .whitespace {
            pos += 1
        }
    }

    func byteStart() -> Int {
        if pos < tokens.count {
            return tokens[pos].range.lowerBound
        } else if !tokens.isEmpty {
            return tokens[tokens.count - 1].range.upperBound
        }
        return 0
    }

    func byteEnd() -> Int {
        byteStart()
    }

    // MARK: - Document

    mutating func parseDocument() -> CSTNode {
        let startToken = pos
        let startByte = byteStart()
        var children: [CSTNode] = []

        skipWhitespace()

        if !atEnd {
            let valueNode = parseValue()
            children.append(valueNode)
        }

        skipWhitespace()

        // Trailing garbage
        while !atEnd {
            let garbageStart = pos
            let garbageByteStart = byteStart()
            let t = advance()
            errors.append(ParseError(
                range: t.range,
                message: "Unexpected content after top-level value",
                code: "json.trailing-content"
            ))
            skipWhitespace()
            let node = CSTNode(
                kind: .error,
                tokenRange: garbageStart..<pos,
                byteRange: garbageByteStart..<byteEnd(),
                children: []
            )
            children.append(node)
            skipWhitespace()
        }

        let endByte: Int
        if !tokens.isEmpty {
            endByte = tokens[tokens.count - 1].range.upperBound
        } else {
            endByte = 0
        }

        return CSTNode(
            kind: .document,
            tokenRange: startToken..<pos,
            byteRange: startByte..<endByte,
            children: children
        )
    }

    // MARK: - Value

    mutating func parseValue() -> CSTNode {
        skipWhitespace()
        let startToken = pos
        let startByte = byteStart()

        guard let token = peek() else {
            errors.append(ParseError(
                range: startByte..<startByte,
                message: "Unexpected end of input",
                code: "json.unexpected-eof"
            ))
            return CSTNode(kind: .error, tokenRange: startToken..<pos, byteRange: startByte..<startByte, children: [])
        }

        switch token.kind {
        case .leftBrace:
            if depth >= Parser.maxDepth {
                errors.append(ParseError(
                    range: token.range,
                    message: "Maximum nesting depth exceeded",
                    code: "json.max-depth"
                ))
                let _ = advance()
                return CSTNode(kind: .error, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: [])
            }
            let obj = parseObject()
            return CSTNode(kind: .value, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: [obj])
        case .leftBracket:
            if depth >= Parser.maxDepth {
                errors.append(ParseError(
                    range: token.range,
                    message: "Maximum nesting depth exceeded",
                    code: "json.max-depth"
                ))
                let _ = advance()
                return CSTNode(kind: .error, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: [])
            }
            let arr = parseArray()
            return CSTNode(kind: .value, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: [arr])
        case .string, .number, .true, .false, .null:
            let _ = advance()
            return CSTNode(kind: .value, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: [])
        default:
            errors.append(ParseError(
                range: token.range,
                message: "Unexpected token '\(token.text)'",
                code: "json.unexpected-token"
            ))
            let _ = advance()
            return CSTNode(kind: .error, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: [])
        }
    }

    // MARK: - Object

    mutating func parseObject() -> CSTNode {
        let startToken = pos
        let startByte = byteStart()
        var children: [CSTNode] = []

        let _ = advance() // consume '{'
        depth += 1
        skipWhitespace()

        var first = true
        while !atEnd {
            skipWhitespace()
            guard let next = peek() else { break }

            if next.kind == .rightBrace {
                let _ = advance()
                depth -= 1
                return CSTNode(kind: .object, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: children)
            }

            if !first {
                if next.kind == .comma {
                    let _ = advance()
                    skipWhitespace()
                    // trailing comma check
                    if let afterComma = peek(), afterComma.kind == .rightBrace {
                        errors.append(ParseError(
                            range: next.range,
                            message: "Trailing comma in object",
                            code: "json.trailing-comma"
                        ))
                        let _ = advance()
                        depth -= 1
                        return CSTNode(kind: .object, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: children)
                    }
                } else {
                    errors.append(ParseError(
                        range: next.range,
                        message: "Expected ',' or '}' in object",
                        code: "json.expected-comma-or-brace"
                    ))
                    // try to recover: if it looks like a string key, keep parsing
                    if next.kind != .string {
                        let errStart = pos
                        let errByteStart = byteStart()
                        let _ = advance()
                        children.append(CSTNode(kind: .error, tokenRange: errStart..<pos, byteRange: errByteStart..<byteEnd(), children: []))
                        continue
                    }
                }
            }
            first = false

            let member = parseMember()
            children.append(member)
        }

        // Unterminated object
        errors.append(ParseError(
            range: byteEnd()..<byteEnd(),
            message: "Unterminated object",
            code: "json.unterminated-object"
        ))
        depth -= 1
        return CSTNode(kind: .object, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: children)
    }

    // MARK: - Member

    mutating func parseMember() -> CSTNode {
        let startToken = pos
        let startByte = byteStart()
        var children: [CSTNode] = []

        skipWhitespace()

        // Key
        guard let keyToken = peek() else {
            errors.append(ParseError(
                range: byteEnd()..<byteEnd(),
                message: "Expected string key",
                code: "json.expected-key"
            ))
            return CSTNode(kind: .error, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: [])
        }

        if keyToken.kind == .string {
            let keyStart = pos
            let keyByteStart = byteStart()
            let _ = advance()
            children.append(CSTNode(kind: .value, tokenRange: keyStart..<pos, byteRange: keyByteStart..<byteEnd(), children: []))
        } else {
            errors.append(ParseError(
                range: keyToken.range,
                message: "Expected string key, got '\(keyToken.text)'",
                code: "json.expected-key"
            ))
            // Try to use this token as a key anyway
            let keyStart = pos
            let keyByteStart = byteStart()
            let _ = advance()
            children.append(CSTNode(kind: .error, tokenRange: keyStart..<pos, byteRange: keyByteStart..<byteEnd(), children: []))
        }

        skipWhitespace()

        // Colon
        if let colonToken = peek(), colonToken.kind == .colon {
            let _ = advance()
        } else {
            let bytePos = byteEnd()
            errors.append(ParseError(
                range: bytePos..<bytePos,
                message: "Expected ':' after key",
                code: "json.expected-colon"
            ))
            // attempt to parse value anyway
        }

        skipWhitespace()

        // Value
        if atEnd {
            errors.append(ParseError(
                range: byteEnd()..<byteEnd(),
                message: "Expected value after ':'",
                code: "json.expected-value"
            ))
            let errStart = pos
            children.append(CSTNode(kind: .error, tokenRange: errStart..<pos, byteRange: byteEnd()..<byteEnd(), children: []))
        } else if let next = peek(), next.kind == .rightBrace || next.kind == .rightBracket || next.kind == .comma {
            errors.append(ParseError(
                range: next.range,
                message: "Expected value after ':'",
                code: "json.expected-value"
            ))
            let errStart = pos
            children.append(CSTNode(kind: .error, tokenRange: errStart..<pos, byteRange: byteEnd()..<byteEnd(), children: []))
        } else {
            let valueNode = parseValue()
            children.append(valueNode)
        }

        return CSTNode(kind: .member, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: children)
    }

    // MARK: - Array

    mutating func parseArray() -> CSTNode {
        let startToken = pos
        let startByte = byteStart()
        var children: [CSTNode] = []

        let _ = advance() // consume '['
        depth += 1
        skipWhitespace()

        var first = true
        while !atEnd {
            skipWhitespace()
            guard let next = peek() else { break }

            if next.kind == .rightBracket {
                let _ = advance()
                depth -= 1
                return CSTNode(kind: .array, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: children)
            }

            if !first {
                if next.kind == .comma {
                    let _ = advance()
                    skipWhitespace()
                    // trailing comma check
                    if let afterComma = peek(), afterComma.kind == .rightBracket {
                        errors.append(ParseError(
                            range: next.range,
                            message: "Trailing comma in array",
                            code: "json.trailing-comma"
                        ))
                        let _ = advance()
                        depth -= 1
                        return CSTNode(kind: .array, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: children)
                    }
                    // double comma
                    if let afterComma = peek(), afterComma.kind == .comma {
                        errors.append(ParseError(
                            range: next.range,
                            message: "Expected value between commas",
                            code: "json.expected-value"
                        ))
                        let errStart = pos
                        children.append(CSTNode(kind: .error, tokenRange: errStart..<pos, byteRange: byteEnd()..<byteEnd(), children: []))
                        continue
                    }
                } else {
                    errors.append(ParseError(
                        range: next.range,
                        message: "Expected ',' or ']' in array",
                        code: "json.expected-comma-or-bracket"
                    ))
                }
            }
            first = false

            let valueNode = parseValue()
            children.append(valueNode)
        }

        // Unterminated array
        errors.append(ParseError(
            range: byteEnd()..<byteEnd(),
            message: "Unterminated array",
            code: "json.unterminated-array"
        ))
        depth -= 1
        return CSTNode(kind: .array, tokenRange: startToken..<pos, byteRange: startByte..<byteEnd(), children: children)
    }
}
