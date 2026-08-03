import Testing
import DTConfigCore

@Suite("LineIndex Tests")
struct LineIndexTests {

    // MARK: - Basic

    @Test("Single line, no trailing newline")
    func singleLineNoNewline() {
        let idx = LineIndex("hello")
        #expect(idx.lineCount == 1)
        #expect(idx.byteCount == 5)
        #expect(idx.position(at: 0) == .init(line: 1, column: 1))
        #expect(idx.position(at: 4) == .init(line: 1, column: 5))
    }

    @Test("Single line with trailing newline")
    func singleLineTrailingNewline() {
        let idx = LineIndex("hello\n")
        #expect(idx.lineCount == 2)
        #expect(idx.position(at: 0) == .init(line: 1, column: 1))
        #expect(idx.position(at: 5) == .init(line: 1, column: 6)) // the \n itself
        #expect(idx.position(at: 6) == .init(line: 2, column: 1)) // past \n
    }

    @Test("Two lines, no trailing newline")
    func twoLinesNoTrailing() {
        let idx = LineIndex("ab\ncd")
        #expect(idx.lineCount == 2)
        #expect(idx.position(at: 0) == .init(line: 1, column: 1))
        #expect(idx.position(at: 1) == .init(line: 1, column: 2))
        #expect(idx.position(at: 2) == .init(line: 1, column: 3)) // the \n
        #expect(idx.position(at: 3) == .init(line: 2, column: 1))
        #expect(idx.position(at: 4) == .init(line: 2, column: 2))
    }

    // MARK: - CRLF

    @Test("CRLF treated as single newline")
    func crlf() {
        let idx = LineIndex("ab\r\ncd")
        #expect(idx.lineCount == 2)
        #expect(idx.byteCount == 6)
        #expect(idx.position(at: 0) == .init(line: 1, column: 1))
        #expect(idx.position(at: 2) == .init(line: 1, column: 3)) // CR
        #expect(idx.position(at: 3) == .init(line: 1, column: 4)) // LF
        #expect(idx.position(at: 4) == .init(line: 2, column: 1))
        #expect(idx.position(at: 5) == .init(line: 2, column: 2))
    }

    @Test("Multiple CRLF lines")
    func multipleCRLF() {
        let idx = LineIndex("a\r\nb\r\nc")
        #expect(idx.lineCount == 3)
        #expect(idx.position(at: 0) == .init(line: 1, column: 1)) // a
        #expect(idx.position(at: 3) == .init(line: 2, column: 1)) // b
        #expect(idx.position(at: 6) == .init(line: 3, column: 1)) // c
    }

    @Test("CRLF with trailing newline")
    func crlfTrailing() {
        let idx = LineIndex("a\r\n")
        #expect(idx.lineCount == 2)
        #expect(idx.position(at: 3) == .init(line: 2, column: 1))
    }

    // MARK: - Non-ASCII

    @Test("Non-ASCII: multi-byte UTF-8 characters")
    func nonASCII() {
        // "aé" — é is 2 bytes in UTF-8 (0xC3 0xA9)
        let idx = LineIndex("aé\nb")
        #expect(idx.byteCount == 5)
        #expect(idx.position(at: 0) == .init(line: 1, column: 1)) // a
        #expect(idx.position(at: 1) == .init(line: 1, column: 2)) // start of é
        #expect(idx.position(at: 2) == .init(line: 1, column: 3)) // second byte of é
        #expect(idx.position(at: 3) == .init(line: 1, column: 4)) // \n
        #expect(idx.position(at: 4) == .init(line: 2, column: 1)) // b
    }

    @Test("Emoji (4-byte UTF-8)")
    func emoji() {
        // 😀 is 4 bytes: F0 9F 98 80
        let idx = LineIndex("😀\nx")
        #expect(idx.byteCount == 6)
        #expect(idx.position(at: 0) == .init(line: 1, column: 1))
        #expect(idx.position(at: 4) == .init(line: 1, column: 5)) // \n
        #expect(idx.position(at: 5) == .init(line: 2, column: 1)) // x
    }

    // MARK: - Edge Cases

    @Test("Empty string")
    func emptyString() {
        let idx = LineIndex("")
        #expect(idx.lineCount == 1)
        #expect(idx.byteCount == 0)
        #expect(idx.position(at: 0) == .init(line: 1, column: 1))
    }

    @Test("Offset past end is clamped")
    func pastEnd() {
        let idx = LineIndex("abc")
        #expect(idx.position(at: 100) == .init(line: 1, column: 4))
    }

    @Test("Negative offset is clamped to zero")
    func negativeOffset() {
        let idx = LineIndex("abc")
        #expect(idx.position(at: -5) == .init(line: 1, column: 1))
    }

    @Test("Bare CR (no LF) is a line break")
    func bareCR() {
        let idx = LineIndex("a\rb")
        #expect(idx.lineCount == 2)
        #expect(idx.position(at: 0) == .init(line: 1, column: 1))
        #expect(idx.position(at: 1) == .init(line: 1, column: 2)) // CR
        #expect(idx.position(at: 2) == .init(line: 2, column: 1))
    }

    @Test("Consecutive newlines")
    func consecutiveNewlines() {
        let idx = LineIndex("a\n\nb")
        #expect(idx.lineCount == 3)
        #expect(idx.position(at: 0) == .init(line: 1, column: 1))
        #expect(idx.position(at: 2) == .init(line: 2, column: 1)) // empty line
        #expect(idx.position(at: 3) == .init(line: 3, column: 1))
    }

    // MARK: - Realistic JSON

    @Test("JSON document line positions")
    func jsonDocument() {
        let json = """
        {
          "model": "test.ckpt",
          "width": 1024
        }
        """
        let idx = LineIndex(json)
        #expect(idx.lineCount == 4)
        #expect(idx.position(at: 0) == .init(line: 1, column: 1)) // {
    }
}
