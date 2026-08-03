/// The semantic role of a token in a JSON document.
public enum SyntaxRole: Sendable, Equatable {
    case key
    case stringValue
    case numberValue
    case boolValue
    case nullValue
    case punctuation
    case unknown
}

/// A byte range in the document tagged with its syntax role.
public struct SyntaxSpan: Sendable, Equatable {
    public let byteRange: Range<Int>
    public let role: SyntaxRole

    public init(byteRange: Range<Int>, role: SyntaxRole) {
        self.byteRange = byteRange
        self.role = role
    }
}

extension ParseResult {
    /// Compute syntax spans from the parse tree.
    ///
    /// Works on partially-broken documents because the lexer always produces
    /// tokens and the parser always produces a CST (with error nodes for
    /// unrecoverable input).
    public func syntaxSpans() -> [SyntaxSpan] {
        var roles = [SyntaxRole?](repeating: nil, count: tokens.count)
        assignContextRoles(for: root, isKey: false, roles: &roles)

        // Second pass: assign default roles for unclaimed tokens.
        for i in 0..<tokens.count where roles[i] == nil {
            roles[i] = Self.defaultRole(for: tokens[i].kind)
        }

        var spans: [SyntaxSpan] = []
        spans.reserveCapacity(tokens.count)
        for (i, role) in roles.enumerated() {
            if let role {
                spans.append(SyntaxSpan(byteRange: tokens[i].range, role: role))
            }
        }
        return spans
    }

    // MARK: - Pass 1: context-dependent roles

    /// Walk the CST and mark string tokens that are object keys vs. values.
    /// Other token kinds are left nil for the default-role pass.
    private func assignContextRoles(
        for node: CSTNode, isKey: Bool, roles: inout [SyntaxRole?]
    ) {
        switch node.kind {
        case .member:
            // First child is the key, second is the value.
            for (i, child) in node.children.enumerated() {
                assignContextRoles(for: child, isKey: i == 0, roles: &roles)
            }

        case .value:
            if node.children.isEmpty {
                // Leaf value node — assign role to string tokens based on context.
                for i in node.tokenRange where i < tokens.count {
                    if tokens[i].kind == .string {
                        roles[i] = isKey ? .key : .stringValue
                    }
                }
            } else {
                for child in node.children {
                    assignContextRoles(for: child, isKey: isKey, roles: &roles)
                }
            }

        case .object, .array, .document:
            for child in node.children {
                assignContextRoles(for: child, isKey: false, roles: &roles)
            }

        case .error:
            for i in node.tokenRange where i < tokens.count {
                if tokens[i].kind != .whitespace && roles[i] == nil {
                    roles[i] = .unknown
                }
            }
        }
    }

    // MARK: - Pass 2: token-kind fallback

    private static func defaultRole(for kind: TokenKind) -> SyntaxRole? {
        switch kind {
        case .string:       return .stringValue
        case .number:       return .numberValue
        case .true, .false: return .boolValue
        case .null:         return .nullValue
        case .leftBrace, .rightBrace, .leftBracket, .rightBracket, .colon, .comma:
            return .punctuation
        case .unknown:      return .unknown
        case .whitespace:   return nil
        }
    }
}
