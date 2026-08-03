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

    /// Convert a UTF-16 offset back to a byte offset.
    ///
    /// Binary search for the first byte where `byteToUTF16[byte] >= utf16`.
    /// When a multi-byte scalar maps several byte positions to the same
    /// UTF-16 offset, this returns the first byte of that scalar.
    public func byteOffset(forUTF16Offset utf16: Int) -> Int {
        if utf16 <= 0 { return 0 }
        let count = byteToUTF16.count
        if count == 0 { return 0 }
        if utf16 >= byteToUTF16[count - 1] { return count - 1 }
        // Binary search: find first index where byteToUTF16[i] >= utf16.
        var lo = 0
        var hi = count
        while lo < hi {
            let mid = (lo + hi) / 2
            if byteToUTF16[mid] < utf16 {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return lo
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
