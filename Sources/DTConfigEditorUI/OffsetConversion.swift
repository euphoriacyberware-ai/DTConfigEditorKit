/// Maps UTF-8 byte offsets (used by the lexer/CST) to UTF-16 code-unit
/// offsets (used by NSTextContentManager / NSString).
///
/// Built once per text snapshot and reused for every span and diagnostic
/// in a single decoration pass.
public struct OffsetTable: Sendable, Equatable {
    /// `byteToUTF16[i]` is the UTF-16 offset that corresponds to byte
    /// offset `i`.  Length is `utf8.count + 1` (the sentinel at the end
    /// represents the past-the-end position).
    private let byteToUTF16: [Int]

    public init(_ text: String) {
        var table: [Int] = []
        table.reserveCapacity(text.utf8.count + 1)
        var utf16Pos = 0
        for scalar in text.unicodeScalars {
            let utf8Len = Self.utf8Width(scalar)
            for _ in 0..<utf8Len {
                table.append(utf16Pos)
            }
            utf16Pos += Self.utf16Width(scalar)
        }
        table.append(utf16Pos) // sentinel
        self.byteToUTF16 = table
    }

    /// Convert a single byte offset to the corresponding UTF-16 offset.
    public func utf16Offset(forByteOffset byte: Int) -> Int {
        if byte < 0 { return 0 }
        if byte >= byteToUTF16.count {
            return byteToUTF16.isEmpty ? 0 : byteToUTF16[byteToUTF16.count - 1]
        }
        return byteToUTF16[byte]
    }

    /// Convert a byte range to the corresponding UTF-16 range.
    public func utf16Range(forByteRange range: Range<Int>) -> Range<Int> {
        utf16Offset(forByteOffset: range.lowerBound)..<utf16Offset(forByteOffset: range.upperBound)
    }

    // MARK: - Width helpers

    private static func utf8Width(_ scalar: Unicode.Scalar) -> Int {
        let v = scalar.value
        if v <= 0x7F   { return 1 }
        if v <= 0x7FF  { return 2 }
        if v <= 0xFFFF { return 3 }
        return 4
    }

    private static func utf16Width(_ scalar: Unicode.Scalar) -> Int {
        scalar.value <= 0xFFFF ? 1 : 2
    }
}
