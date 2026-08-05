public struct ParseError: Sendable, Equatable {
    public let range: Range<Int>
    public let message: String
    public let code: String

    public init(range: Range<Int>, message: String, code: String) {
        self.range = range
        self.message = message
        self.code = code
    }
}
