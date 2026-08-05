public enum CSTNodeKind: Sendable, Equatable {
    case document
    case object
    case array
    case member
    case value
    case error
}

public struct CSTNode: Sendable, Equatable {
    public let kind: CSTNodeKind
    public let tokenRange: Range<Int>
    public let byteRange: Range<Int>
    public let children: [CSTNode]

    public init(kind: CSTNodeKind, tokenRange: Range<Int>, byteRange: Range<Int>, children: [CSTNode]) {
        self.kind = kind
        self.tokenRange = tokenRange
        self.byteRange = byteRange
        self.children = children
    }
}
