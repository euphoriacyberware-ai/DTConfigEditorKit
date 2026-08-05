public enum Lexer {
    public static func tokenize(_ source: String) -> [Token] {
        let bytes = Array(source.utf8)
        let count = bytes.count
        var tokens: [Token] = []
        var pos = 0

        while pos < count {
            let start = pos
            let byte = bytes[pos]

            switch byte {
            case UInt8(ascii: "{"):
                pos += 1
                tokens.append(Token(kind: .leftBrace, range: start..<pos, text: "{"))
            case UInt8(ascii: "}"):
                pos += 1
                tokens.append(Token(kind: .rightBrace, range: start..<pos, text: "}"))
            case UInt8(ascii: "["):
                pos += 1
                tokens.append(Token(kind: .leftBracket, range: start..<pos, text: "["))
            case UInt8(ascii: "]"):
                pos += 1
                tokens.append(Token(kind: .rightBracket, range: start..<pos, text: "]"))
            case UInt8(ascii: ":"):
                pos += 1
                tokens.append(Token(kind: .colon, range: start..<pos, text: ":"))
            case UInt8(ascii: ","):
                pos += 1
                tokens.append(Token(kind: .comma, range: start..<pos, text: ","))
            case UInt8(ascii: "\""):
                pos = scanString(bytes: bytes, from: pos)
                let text = makeText(bytes: bytes, start: start, end: pos)
                tokens.append(Token(kind: .string, range: start..<pos, text: text))
            case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
                pos = scanNumber(bytes: bytes, from: pos)
                let text = makeText(bytes: bytes, start: start, end: pos)
                tokens.append(Token(kind: .number, range: start..<pos, text: text))
            case UInt8(ascii: "t"):
                if matchKeyword(bytes: bytes, from: pos, keyword: trueBytes) {
                    pos += 4
                    tokens.append(Token(kind: .true, range: start..<pos, text: "true"))
                } else {
                    pos += 1
                    let text = makeText(bytes: bytes, start: start, end: pos)
                    tokens.append(Token(kind: .unknown, range: start..<pos, text: text))
                }
            case UInt8(ascii: "f"):
                if matchKeyword(bytes: bytes, from: pos, keyword: falseBytes) {
                    pos += 5
                    tokens.append(Token(kind: .false, range: start..<pos, text: "false"))
                } else {
                    pos += 1
                    let text = makeText(bytes: bytes, start: start, end: pos)
                    tokens.append(Token(kind: .unknown, range: start..<pos, text: text))
                }
            case UInt8(ascii: "n"):
                if matchKeyword(bytes: bytes, from: pos, keyword: nullBytes) {
                    pos += 4
                    tokens.append(Token(kind: .null, range: start..<pos, text: "null"))
                } else {
                    pos += 1
                    let text = makeText(bytes: bytes, start: start, end: pos)
                    tokens.append(Token(kind: .unknown, range: start..<pos, text: text))
                }
            case UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\n"), UInt8(ascii: "\r"):
                pos = scanWhitespace(bytes: bytes, from: pos)
                let text = makeText(bytes: bytes, start: start, end: pos)
                tokens.append(Token(kind: .whitespace, range: start..<pos, text: text))
            default:
                pos += 1
                let text = makeText(bytes: bytes, start: start, end: pos)
                tokens.append(Token(kind: .unknown, range: start..<pos, text: text))
            }
        }

        return tokens
    }

    private static let trueBytes: [UInt8] = [UInt8(ascii: "t"), UInt8(ascii: "r"), UInt8(ascii: "u"), UInt8(ascii: "e")]
    private static let falseBytes: [UInt8] = [UInt8(ascii: "f"), UInt8(ascii: "a"), UInt8(ascii: "l"), UInt8(ascii: "s"), UInt8(ascii: "e")]
    private static let nullBytes: [UInt8] = [UInt8(ascii: "n"), UInt8(ascii: "u"), UInt8(ascii: "l"), UInt8(ascii: "l")]

    private static func matchKeyword(bytes: [UInt8], from pos: Int, keyword: [UInt8]) -> Bool {
        guard pos + keyword.count <= bytes.count else { return false }
        for i in 0..<keyword.count {
            if bytes[pos + i] != keyword[i] { return false }
        }
        return true
    }

    private static func scanString(bytes: [UInt8], from start: Int) -> Int {
        var pos = start + 1 // skip opening quote
        let count = bytes.count
        while pos < count {
            let byte = bytes[pos]
            if byte == UInt8(ascii: "\\") {
                pos += 2 // skip escape and next byte
                if pos > count { pos = count }
            } else if byte == UInt8(ascii: "\"") {
                pos += 1
                return pos
            } else {
                pos += 1
            }
        }
        return pos // unterminated string — return EOF
    }

    private static func scanNumber(bytes: [UInt8], from start: Int) -> Int {
        var pos = start
        let count = bytes.count

        // optional minus
        if pos < count && bytes[pos] == UInt8(ascii: "-") {
            pos += 1
        }

        // integer part
        if pos < count && bytes[pos] == UInt8(ascii: "0") {
            pos += 1
        } else {
            while pos < count && bytes[pos] >= UInt8(ascii: "0") && bytes[pos] <= UInt8(ascii: "9") {
                pos += 1
            }
        }

        // fractional part
        if pos < count && bytes[pos] == UInt8(ascii: ".") {
            pos += 1
            while pos < count && bytes[pos] >= UInt8(ascii: "0") && bytes[pos] <= UInt8(ascii: "9") {
                pos += 1
            }
        }

        // exponent
        if pos < count && (bytes[pos] == UInt8(ascii: "e") || bytes[pos] == UInt8(ascii: "E")) {
            pos += 1
            if pos < count && (bytes[pos] == UInt8(ascii: "+") || bytes[pos] == UInt8(ascii: "-")) {
                pos += 1
            }
            while pos < count && bytes[pos] >= UInt8(ascii: "0") && bytes[pos] <= UInt8(ascii: "9") {
                pos += 1
            }
        }

        return pos
    }

    private static func scanWhitespace(bytes: [UInt8], from start: Int) -> Int {
        var pos = start
        let count = bytes.count
        while pos < count {
            switch bytes[pos] {
            case UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\n"), UInt8(ascii: "\r"):
                pos += 1
            default:
                return pos
            }
        }
        return pos
    }

    private static func makeText(bytes: [UInt8], start: Int, end: Int) -> String {
        String(decoding: bytes[start..<end], as: UTF8.self)
    }
}
