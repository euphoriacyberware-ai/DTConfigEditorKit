/// Maps byte offsets to line:column positions.
///
/// Works on raw UTF-8 bytes so that byte offsets from the parser's CST
/// translate directly. Lines are 1-based; columns are 1-based byte offsets
/// within the line.
public struct LineIndex: Sendable {
    /// Byte offset of the start of each line (0-based).
    /// `lineStarts[0]` is always 0.
    private let lineStarts: [Int]

    /// Total byte count of the source.
    public let byteCount: Int

    /// Number of lines in the source (always >= 1 for non-empty input).
    public var lineCount: Int { lineStarts.count }

    public init(_ source: String) {
        let utf8 = Array(source.utf8)
        self.byteCount = utf8.count
        var starts: [Int] = [0]
        var i = 0
        while i < utf8.count {
            if utf8[i] == 0x0D /* CR */ {
                if i + 1 < utf8.count && utf8[i + 1] == 0x0A /* LF */ {
                    // CRLF — single newline
                    starts.append(i + 2)
                    i += 2
                } else {
                    // bare CR
                    starts.append(i + 1)
                    i += 1
                }
            } else if utf8[i] == 0x0A /* LF */ {
                starts.append(i + 1)
                i += 1
            } else {
                i += 1
            }
        }
        self.lineStarts = starts
    }

    /// A 1-based line and column position.
    public struct Position: Sendable, Equatable {
        public let line: Int
        public let column: Int

        public init(line: Int, column: Int) {
            self.line = line
            self.column = column
        }
    }

    /// Returns the 1-based line and column for a byte offset.
    ///
    /// Offsets past the end of the source are clamped to the last valid position.
    public func position(at byteOffset: Int) -> Position {
        let clamped = max(0, min(byteOffset, byteCount))

        // Binary search for the line containing this offset.
        var lo = 0
        var hi = lineStarts.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if lineStarts[mid] <= clamped {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        // lo is now one past the last line whose start <= clamped.
        let lineIndex = lo - 1
        let column = clamped - lineStarts[lineIndex]
        return Position(line: lineIndex + 1, column: column + 1)
    }
}
