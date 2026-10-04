// Decoding and encoding of JSON string literals, shared by the parser, validator,
// formatter, completion engine and downstream modules.

public enum JSONString {

    /// Decode a string token's raw text (including its quotes) into its value.
    ///
    /// Tolerates an unterminated literal (no closing quote) and malformed escapes,
    /// which are kept verbatim, since the editor decodes partially typed text.
    public static func decode(_ raw: String) -> String {
        guard raw.count >= 2, raw.hasPrefix("\"") else { return raw }
        let body = raw.dropFirst()
        let inner: Substring
        if body.hasSuffix("\""),
           body.dropLast().reversed().prefix(while: { $0 == "\\" }).count % 2 == 0 {
            inner = body.dropLast()
        } else {
            inner = body // unterminated
        }
        guard inner.contains("\\") else { return String(inner) }

        var result = ""
        var pendingHighSurrogate: UInt32?
        var it = inner.makeIterator()
        while let ch = it.next() {
            guard ch == "\\" else {
                flush(&pendingHighSurrogate, into: &result)
                result.append(ch)
                continue
            }
            guard let esc = it.next() else {
                flush(&pendingHighSurrogate, into: &result)
                result.append("\\")
                break
            }
            if esc != "u" { flush(&pendingHighSurrogate, into: &result) }
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
                guard hex.count == 4, let code = UInt32(hex, radix: 16) else {
                    flush(&pendingHighSurrogate, into: &result)
                    result.append("\\u")
                    result.append(hex)
                    continue
                }
                if (0xD800...0xDBFF).contains(code) {
                    flush(&pendingHighSurrogate, into: &result)
                    pendingHighSurrogate = code
                } else if (0xDC00...0xDFFF).contains(code), let high = pendingHighSurrogate {
                    pendingHighSurrogate = nil
                    let combined = 0x10000 + ((high - 0xD800) << 10) + (code - 0xDC00)
                    if let scalar = Unicode.Scalar(combined) { result.unicodeScalars.append(scalar) }
                } else if let scalar = Unicode.Scalar(code) {
                    flush(&pendingHighSurrogate, into: &result)
                    result.unicodeScalars.append(scalar)
                } else {
                    // A lone low surrogate.
                    flush(&pendingHighSurrogate, into: &result)
                    result.append("\u{FFFD}")
                }
            default:
                result.append("\\")
                result.append(esc)
            }
        }
        flush(&pendingHighSurrogate, into: &result)
        return result
    }

    /// Encode a value as a quoted JSON string literal.
    public static func quote(_ value: String) -> String {
        var out = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16)
                out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out + "\""
    }

    /// An unpaired high surrogate becomes U+FFFD, as JSONSerialization would.
    private static func flush(_ pending: inout UInt32?, into result: inout String) {
        if pending != nil {
            result.append("\u{FFFD}")
            pending = nil
        }
    }
}
