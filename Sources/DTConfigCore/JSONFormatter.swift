/// Pretty-printer and key-sorter operating on ``ParseResult``.
/// No Foundation dependency — works entirely on ``CSTNode`` and tokens.
public enum JSONFormatter {

    /// Pretty-print the source string using 2-space indentation.
    /// Error nodes are emitted verbatim. Numeric literals are preserved exactly.
    public static func format(_ source: String) -> String {
        let result = Parser.parse(source)
        var out = ""
        formatNode(result.root, tokens: result.tokens, source: source, indent: 0, out: &out)
        return out
    }

    /// Reorder object keys alphabetically (recursively). Non-object content
    /// is unchanged. Whitespace/separator style is preserved between members.
    public static func sortKeys(_ source: String) -> String {
        let result = Parser.parse(source)
        return sortNode(result.root, tokens: result.tokens, source: source)
    }

    /// Returns the decoded key name of the deepest ``member`` node whose
    /// byte range contains `offset`, or nil if `offset` is not inside a member.
    public static func keyAtOffset(_ offset: Int, in source: String) -> String? {
        let result = Parser.parse(source)
        return deepestKey(at: offset, node: result.root, tokens: result.tokens)
    }

    /// Returns the byte offset of the key token for the first top-level member
    /// with the given decoded key, or nil if not found.
    public static func offsetOfKey(_ key: String, in source: String) -> Int? {
        let result = Parser.parse(source)
        return firstKeyOffset(key, node: result.root, tokens: result.tokens)
    }

    // MARK: - Format implementation

    private static func formatNode(
        _ node: CSTNode, tokens: [Token], source: String,
        indent: Int, out: inout String
    ) {
        switch node.kind {
        case .document:
            for child in node.children {
                formatNode(child, tokens: tokens, source: source, indent: indent, out: &out)
            }

        case .value:
            if node.children.isEmpty {
                // Leaf value — emit token text verbatim (preserves numeric literals).
                appendSignificantToken(node, tokens: tokens, out: &out)
            } else {
                for child in node.children {
                    formatNode(child, tokens: tokens, source: source, indent: indent, out: &out)
                }
            }

        case .object:
            let members = node.children.filter { $0.kind == .member }
            if members.isEmpty {
                out += "{}"
            } else {
                out += "{\n"
                for (i, member) in members.enumerated() {
                    appendIndent(indent + 1, out: &out)
                    formatMember(member, tokens: tokens, source: source, indent: indent + 1, out: &out)
                    if i < members.count - 1 {
                        out += ","
                    }
                    out += "\n"
                }
                appendIndent(indent, out: &out)
                out += "}"
            }

        case .array:
            let elements = node.children.filter { $0.kind == .value || $0.kind == .error }
            if elements.isEmpty {
                out += "[]"
            } else {
                out += "[\n"
                for (i, element) in elements.enumerated() {
                    appendIndent(indent + 1, out: &out)
                    formatNode(element, tokens: tokens, source: source, indent: indent + 1, out: &out)
                    if i < elements.count - 1 {
                        out += ","
                    }
                    out += "\n"
                }
                appendIndent(indent, out: &out)
                out += "]"
            }

        case .member:
            formatMember(node, tokens: tokens, source: source, indent: indent, out: &out)

        case .error:
            // Emit source text as-is for error nodes.
            let bytes = Array(source.utf8)
            let lo = max(0, node.byteRange.lowerBound)
            let hi = min(bytes.count, node.byteRange.upperBound)
            if lo < hi {
                out += String(decoding: bytes[lo..<hi], as: UTF8.self)
            }
        }
    }

    private static func formatMember(
        _ node: CSTNode, tokens: [Token], source: String,
        indent: Int, out: inout String
    ) {
        guard node.kind == .member else { return }
        // First child = key, second child = value.
        if node.children.count >= 1 {
            appendSignificantToken(node.children[0], tokens: tokens, out: &out)
        }
        out += ": "
        if node.children.count >= 2 {
            formatNode(node.children[1], tokens: tokens, source: source, indent: indent, out: &out)
        }
    }

    private static func appendSignificantToken(
        _ node: CSTNode, tokens: [Token], out: inout String
    ) {
        for i in node.tokenRange where i < tokens.count {
            if tokens[i].kind != .whitespace {
                out += tokens[i].text
                return
            }
        }
    }

    private static func appendIndent(_ level: Int, out: inout String) {
        for _ in 0..<level {
            out += "  "
        }
    }

    // MARK: - Sort implementation

    private static func sortNode(
        _ node: CSTNode, tokens: [Token], source: String
    ) -> String {
        let bytes = Array(source.utf8)

        switch node.kind {
        case .document:
            var result = ""
            var lastEnd = node.byteRange.lowerBound
            for child in node.children {
                // Preserve any content between children (whitespace).
                if child.byteRange.lowerBound > lastEnd {
                    result += slice(bytes, lastEnd..<child.byteRange.lowerBound)
                }
                result += sortNode(child, tokens: tokens, source: source)
                lastEnd = child.byteRange.upperBound
            }
            if lastEnd < node.byteRange.upperBound {
                result += slice(bytes, lastEnd..<node.byteRange.upperBound)
            }
            return result

        case .value:
            if node.children.isEmpty {
                return slice(bytes, node.byteRange)
            }
            var result = ""
            var lastEnd = node.byteRange.lowerBound
            for child in node.children {
                if child.byteRange.lowerBound > lastEnd {
                    result += slice(bytes, lastEnd..<child.byteRange.lowerBound)
                }
                result += sortNode(child, tokens: tokens, source: source)
                lastEnd = child.byteRange.upperBound
            }
            if lastEnd < node.byteRange.upperBound {
                result += slice(bytes, lastEnd..<node.byteRange.upperBound)
            }
            return result

        case .object:
            let members = node.children.filter { $0.kind == .member }
            if members.isEmpty {
                return slice(bytes, node.byteRange)
            }

            // First, recursively sort nested objects inside each member's value.
            var memberTexts: [(key: String, text: String)] = []
            for member in members {
                let key = extractKey(member, tokens: tokens)
                // Sort nested objects in the value child (second child).
                var memberText: String
                if member.children.count >= 2 {
                    let keyChild = member.children[0]
                    let valueChild = member.children[1]
                    let keyText = slice(bytes, keyChild.byteRange)
                    // Content between key and value (colon + whitespace).
                    let between = slice(bytes, keyChild.byteRange.upperBound..<valueChild.byteRange.lowerBound)
                    let sortedValue = sortNode(valueChild, tokens: tokens, source: source)
                    memberText = keyText + between + sortedValue
                } else {
                    memberText = slice(bytes, member.byteRange)
                }
                memberTexts.append((key: key, text: memberText))
            }

            // Extract separators between members (commas + whitespace in the gaps).
            var separators: [String] = []
            for i in 0..<members.count - 1 {
                let gapStart = members[i].byteRange.upperBound
                let gapEnd = members[i + 1].byteRange.lowerBound
                separators.append(slice(bytes, gapStart..<gapEnd))
            }

            // Sort by key.
            let sortedIndices = memberTexts.indices.sorted { memberTexts[$0].key < memberTexts[$1].key }

            // Reassemble: prefix + sorted members with original separators + suffix.
            let prefix = slice(bytes, node.byteRange.lowerBound..<members[0].byteRange.lowerBound)
            let suffix = slice(bytes, members[members.count - 1].byteRange.upperBound..<node.byteRange.upperBound)

            var result = prefix
            for (i, sortedIdx) in sortedIndices.enumerated() {
                result += memberTexts[sortedIdx].text
                if i < separators.count {
                    result += separators[i]
                }
            }
            result += suffix
            return result

        case .array:
            // Recurse into array elements to sort nested objects.
            var result = ""
            var lastEnd = node.byteRange.lowerBound
            for child in node.children {
                if child.byteRange.lowerBound > lastEnd {
                    result += slice(bytes, lastEnd..<child.byteRange.lowerBound)
                }
                result += sortNode(child, tokens: tokens, source: source)
                lastEnd = child.byteRange.upperBound
            }
            if lastEnd < node.byteRange.upperBound {
                result += slice(bytes, lastEnd..<node.byteRange.upperBound)
            }
            return result

        case .member, .error:
            return slice(bytes, node.byteRange)
        }
    }

    private static func extractKey(_ member: CSTNode, tokens: [Token]) -> String {
        guard member.kind == .member, !member.children.isEmpty else { return "" }
        let keyNode = member.children[0]
        for i in keyNode.tokenRange where i < tokens.count {
            if tokens[i].kind == .string {
                return decodeKey(tokens[i].text)
            }
        }
        return ""
    }

    private static func decodeKey(_ raw: String) -> String {
        guard raw.count >= 2, raw.hasPrefix("\"") else { return raw }
        if raw.hasSuffix("\"") {
            return String(raw.dropFirst().dropLast())
        }
        return String(raw.dropFirst())
    }

    private static func slice(_ bytes: [UInt8], _ range: Range<Int>) -> String {
        let lo = max(0, range.lowerBound)
        let hi = min(bytes.count, range.upperBound)
        guard lo < hi else { return "" }
        return String(decoding: bytes[lo..<hi], as: UTF8.self)
    }

    // MARK: - Cursor helpers

    private static func deepestKey(
        at offset: Int, node: CSTNode, tokens: [Token]
    ) -> String? {
        guard node.byteRange.contains(offset) || offset == node.byteRange.upperBound else {
            return nil
        }

        // Try children depth-first; return deepest match.
        for child in node.children {
            if let key = deepestKey(at: offset, node: child, tokens: tokens) {
                return key
            }
        }

        // If this node is a member, return its key.
        if node.kind == .member {
            return extractKey(node, tokens: tokens)
        }

        return nil
    }

    private static func firstKeyOffset(
        _ key: String, node: CSTNode, tokens: [Token]
    ) -> Int? {
        switch node.kind {
        case .document, .value:
            for child in node.children {
                if let offset = firstKeyOffset(key, node: child, tokens: tokens) {
                    return offset
                }
            }
        case .object:
            for child in node.children where child.kind == .member {
                let memberKey = extractKey(child, tokens: tokens)
                if memberKey == key {
                    // Return byte start of the key token.
                    let keyNode = child.children[0]
                    for i in keyNode.tokenRange where i < tokens.count {
                        if tokens[i].kind == .string {
                            return tokens[i].range.lowerBound
                        }
                    }
                    return child.byteRange.lowerBound
                }
            }
        case .array:
            for child in node.children {
                if let offset = firstKeyOffset(key, node: child, tokens: tokens) {
                    return offset
                }
            }
        case .member, .error:
            break
        }
        return nil
    }
}
