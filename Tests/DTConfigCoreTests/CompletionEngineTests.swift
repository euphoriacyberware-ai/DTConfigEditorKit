import Testing
import DTConfigCore
import Foundation

@Suite("Completion Engine Tests")
struct CompletionEngineTests {

    private func fixturesURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    private func loadFixture(_ name: String) throws -> String {
        let url = fixturesURL().appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Fuzz: every byte offset, no crash, valid replacement range

    @Test("No crash at every byte offset",
          arguments: ["DT_krea2_robo.json", "DT_krea2_robo_min.json",
                      "DT_wan2.2_i2v.json", "DT_Control_Example.json",
                      "DT_future_key.json"])
    func everyOffsetNoCrash(fixture: String) throws {
        let json = try loadFixture(fixture)
        let result = Parser.parse(json)
        let byteCount = Array(json.utf8).count

        for offset in 0...byteCount {
            let cr = CompletionEngine.completions(in: result, at: offset)
            // Replacement range must be valid.
            #expect(cr.replacementRange.lowerBound >= 0,
                    "negative lower bound at offset \(offset)")
            #expect(cr.replacementRange.upperBound <= byteCount,
                    "upper bound \(cr.replacementRange.upperBound) > byteCount \(byteCount) at offset \(offset)")
            #expect(cr.replacementRange.lowerBound <= cr.replacementRange.upperBound,
                    "inverted range at offset \(offset)")
        }
    }

    // MARK: - Key completion: already-present keys excluded

    @Test("Already-present keys excluded from key completion")
    func existingKeysExcluded() {
        let json = """
        {"model": "test.ckpt", "width": 1024, }
        """
        let result = Parser.parse(json)
        // Cursor after the trailing comma (the LAST comma), in key position.
        let bytes = Array(json.utf8)
        let lastComma = bytes.lastIndex(of: UInt8(ascii: ","))!
        let cr = CompletionEngine.completions(in: result, at: lastComma + 2)
        let keys = cr.items.map(\.filterText)
        #expect(!keys.contains("model"), "model already present")
        #expect(!keys.contains("width"), "width already present")
        #expect(keys.contains("height"), "height should be offered")
        #expect(keys.contains("sampler"), "sampler should be offered")
    }

    // MARK: - Truncate mid-key

    @Test("Truncated mid-key detects key context")
    func truncatedMidKey() {
        let json = """
        {"model": "test.ckpt", "wid
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        #expect(!cr.items.isEmpty, "Should offer key completions")
        let keys = cr.items.map(\.filterText)
        #expect(keys.contains("width"), "Should match 'wid' prefix")
        #expect(!keys.contains("height"), "'height' doesn't start with 'wid'")
        #expect(!keys.contains("model"), "model already present")
    }

    // MARK: - Truncate mid-value

    @Test("Truncated mid-value detects value context for intEnum")
    func truncatedMidValueIntEnum() {
        let json = """
        {"model": "test.ckpt", "sampler": 1
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        #expect(!cr.items.isEmpty, "Should offer sampler value completions")
        // Partial "1" should match 1, 10-19
        let values = cr.items.map(\.text)
        #expect(values.contains("1"), "Should include 1")
        #expect(values.contains("10"), "Should include 10")
        #expect(!values.contains("2"), "2 doesn't start with '1'")
    }

    @Test("Truncated mid-value detects value context for stringOrIntEnum")
    func truncatedMidValueStringEnum() {
        let json = """
        {"model": "test.ckpt", "compressionArtifacts": "h
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        let labels = cr.items.map(\.filterText)
        #expect(labels.contains("h264"), "Should match 'h' prefix")
        #expect(labels.contains("h265"), "Should match 'h' prefix")
        #expect(!labels.contains("disabled"), "'disabled' doesn't match 'h'")
    }

    // MARK: - Boolean value completion

    @Test("Boolean field offers true/false")
    func boolCompletion() {
        let json = """
        {"model": "test.ckpt", "hiresFix":
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        let values = cr.items.map(\.text)
        #expect(values.contains("true"))
        #expect(values.contains("false"))
    }

    // MARK: - Nullable fields

    @Test("Nullable string offers null")
    func nullableStringCompletion() {
        let json = """
        {"model": "test.ckpt", "upscaler":
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        let values = cr.items.map(\.text)
        #expect(values.contains("null"))
    }

    @Test("Nullable int offers null")
    func nullableIntCompletion() {
        let json = """
        {"model": "test.ckpt", "seed":
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        let values = cr.items.map(\.text)
        #expect(values.contains("null"))
    }

    // MARK: - Nested object completion (LoRA)

    @Test("LoRA object key completion")
    func loraKeyCompletion() {
        let json = """
        {"model": "test.ckpt", "loras": [{"file": "a.ckpt",
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        let keys = cr.items.map(\.filterText)
        #expect(keys.contains("weight"), "Should offer weight")
        #expect(keys.contains("mode"), "Should offer mode")
        #expect(!keys.contains("file"), "file already present")
    }

    @Test("LoRA mode value completion")
    func loraModeCompletion() {
        let json = """
        {"model": "test.ckpt", "loras": [{"file": "a.ckpt", "mode":
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        let values = cr.items.map(\.filterText)
        #expect(values.contains("all"))
        #expect(values.contains("base"))
        #expect(values.contains("refiner"))
    }

    // MARK: - Control importance completion

    @Test("controlImportance value completion")
    func controlImportanceCompletion() {
        let json = """
        {"model": "test.ckpt", "controls": [{"file": "c.ckpt", "controlImportance":
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        let values = cr.items.map(\.filterText)
        #expect(values.contains("balanced"))
        #expect(values.contains("prompt"))
        #expect(values.contains("control"))
    }

    // MARK: - Domain values

    @Test("Domain values included when provided")
    func domainValues() {
        let json = """
        {"model":
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let domain: [FieldPath: [DomainValue]] = [
            .model: [
                DomainValue(value: "sd_xl_base.safetensors", label: "SDXL Base"),
                DomainValue(value: "flux1.safetensors"),
            ],
        ]
        let cr = CompletionEngine.completions(
            in: result, at: offset, domainValues: domain)
        let labels = cr.items.map(\.displayLabel)
        #expect(labels.contains("SDXL Base"))
        #expect(labels.contains("flux1.safetensors"))
    }

    @Test("No completions without domain values for string fields")
    func noDomainNoop() {
        let json = """
        {"model":
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        // model is a plain string with domainPath — no static completions
        #expect(cr.items.isEmpty)
    }

    // MARK: - Empty document / edge cases

    @Test("Empty document returns empty completions")
    func emptyDocument() {
        let result = Parser.parse("")
        let cr = CompletionEngine.completions(in: result, at: 0)
        #expect(cr.items.isEmpty)
    }

    @Test("Opening brace offers key completions")
    func afterOpenBrace() {
        let json = "{"
        let result = Parser.parse(json)
        let cr = CompletionEngine.completions(in: result, at: 1)
        #expect(!cr.items.isEmpty, "Should offer root keys after {")
        let keys = cr.items.map(\.filterText)
        #expect(keys.contains("model"))
    }

    @Test("Cursor before document returns empty")
    func cursorBeforeDocument() {
        let json = """
        {"model": "test.ckpt"}
        """
        let result = Parser.parse(json)
        let cr = CompletionEngine.completions(in: result, at: 0)
        // At byte 0, cursor is at/inside the '{' token — no completion context
        #expect(cr.items.isEmpty)
    }

    @Test("Sampler completions show names")
    func samplerDisplayLabels() {
        let json = """
        {"model": "test.ckpt", "sampler":
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        let display17 = cr.items.first { $0.text == "17" }
        #expect(display17?.displayLabel == "17 (unipctrailing)")
    }

    // MARK: - Key completion with type labels

    @Test("Key completions include type labels")
    func keyTypeLabels() {
        let json = "{"
        let result = Parser.parse(json)
        let cr = CompletionEngine.completions(in: result, at: 1)
        let widthItem = cr.items.first { $0.filterText == "width" }
        #expect(widthItem?.typeLabel == "int")
        let hiresItem = cr.items.first { $0.filterText == "hiresFix" }
        #expect(hiresItem?.typeLabel == "bool")
    }

    // MARK: - No completion after value

    @Test("No completion after a complete value")
    func noCompletionAfterValue() {
        let json = """
        {"model": "test.ckpt"}
        """
        let result = Parser.parse(json)
        // Cursor right after closing brace
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        #expect(cr.items.isEmpty)
    }

    @Test("No completion between key and colon")
    func noCompletionAfterKey() {
        let json = """
        {"model"
        """
        let result = Parser.parse(json)
        let offset = Array(json.utf8).count
        let cr = CompletionEngine.completions(in: result, at: offset)
        // After the key before ':', no completion
        #expect(cr.items.isEmpty)
    }
}
