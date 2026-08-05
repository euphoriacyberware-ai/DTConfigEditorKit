public enum TokenKind: Sendable, Equatable {
    case leftBrace
    case rightBrace
    case leftBracket
    case rightBracket
    case colon
    case comma
    case string
    case number
    case `true`
    case `false`
    case null
    case whitespace
    case unknown
}

public struct Token: Sendable, Equatable {
    public let kind: TokenKind
    public let range: Range<Int>
    public let text: String

    public init(kind: TokenKind, range: Range<Int>, text: String) {
        self.kind = kind
        self.range = range
        self.text = text
    }
}
