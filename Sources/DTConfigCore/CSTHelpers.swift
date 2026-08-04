// Public helpers for navigating a ParseResult's CST.
// These are read-only utilities used by CompletionEngine, FixItApplicator,
// and downstream modules (DTConfigBridge).

extension ParseResult {

    /// Find the root-level object node, if any.
    public func findRootObject() -> CSTNode? {
        for child in root.children where child.kind == .value {
            for grandchild in child.children where grandchild.kind == .object {
                return grandchild
            }
        }
        return nil
    }

    /// Extract the decoded key string from a member's key node.
    public func extractKey(from keyNode: CSTNode) -> String? {
        for i in keyNode.tokenRange where i < tokens.count {
            if tokens[i].kind == .string {
                return decodeKey(tokens[i].text)
            }
        }
        return nil
    }

    /// Collect keys already present in the root-level object.
    public func existingRootKeys() -> Set<String> {
        guard let obj = findRootObject() else { return [] }
        return existingKeys(in: obj)
    }

    /// Collect keys already present in an object node.
    public func existingKeys(in objectNode: CSTNode) -> Set<String> {
        var keys = Set<String>()
        for member in objectNode.children
            where member.kind == .member && !member.children.isEmpty
        {
            if let key = extractKey(from: member.children[0]) {
                keys.insert(key)
            }
        }
        return keys
    }

    /// Compute the byte range to delete when removing a member from an object.
    ///
    /// Includes the adjacent comma and whitespace so the remaining JSON stays valid.
    /// Returns `nil` if the member is not found.
    public func memberRemovalRange(
        forMemberAt memberRange: Range<Int>,
        in objectNode: CSTNode
    ) -> Range<Int>? {
        let members = objectNode.children.filter { $0.kind == .member }
        guard let idx = members.firstIndex(where: { $0.byteRange == memberRange })
        else { return nil }

        if members.count == 1 {
            return memberRange
        }

        if idx == 0 {
            // First member: remove member + gap to next member.
            let nextStart = members[1].byteRange.lowerBound
            return memberRange.lowerBound..<nextStart
        } else {
            // Non-first member: remove gap from previous member + member.
            let prevEnd = members[idx - 1].byteRange.upperBound
            return prevEnd..<memberRange.upperBound
        }
    }

    // MARK: - Private

    private func decodeKey(_ raw: String) -> String {
        guard raw.count >= 2, raw.hasPrefix("\"") else { return raw }
        if raw.hasSuffix("\"") {
            return String(raw.dropFirst().dropLast())
        }
        return String(raw.dropFirst())
    }
}
