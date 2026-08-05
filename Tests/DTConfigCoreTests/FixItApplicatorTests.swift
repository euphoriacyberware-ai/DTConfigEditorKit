import Testing
import DTConfigCore
import Foundation

@Suite("Fix-It Applicator Tests")
struct FixItApplicatorTests {

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

    // MARK: - Basic application

    @Test("Applying a fix-it replaces the target span")
    func basicApply() {
        let source = """
        {"width": 1000, "height": 1024}
        """
        let fixIt = FixIt(range: 10..<14, replacement: "1024", label: "Change to 1024")
        let result = FixItApplicator.apply(fixIt, to: source)
        #expect(result.contains("1024"))
        #expect(!result.contains("1000"))
    }

    // MARK: - Only target span changes

    @Test("Fix-it changes only the target byte span")
    func onlyTargetChanges() {
        let source = """
        {"width": 1000, "height": 1024, "model": "test.ckpt"}
        """
        let fixIt = FixIt(range: 10..<14, replacement: "960", label: "Change to 960")
        let result = FixItApplicator.apply(fixIt, to: source)

        let origBytes = Array(source.utf8)
        let resultBytes = Array(result.utf8)

        // Bytes before the range are identical.
        let prefix = Array(origBytes[0..<fixIt.range.lowerBound])
        let resultPrefix = Array(resultBytes[0..<fixIt.range.lowerBound])
        #expect(prefix == resultPrefix, "Bytes before fix-it range must be identical")

        // Bytes after the range are identical (shifted by size difference).
        let shift = fixIt.replacement.utf8.count - (fixIt.range.upperBound - fixIt.range.lowerBound)
        let origSuffix = Array(origBytes[fixIt.range.upperBound...])
        let resultSuffix = Array(resultBytes[(fixIt.range.upperBound + shift)...])
        #expect(origSuffix == resultSuffix, "Bytes after fix-it range must be identical")
    }

    // MARK: - Multiple-of-64 fix-it end-to-end

    @Test("Applying multiple-of-64 fix-it clears exactly that diagnostic")
    func multipleOf64FixItClearsDiagnostic() {
        let json = """
        {"model": "test.ckpt", "width": 1000, "height": 1024, "loras": [], "controls": []}
        """
        let result = Parser.parse(json)
        let diagnostics = Validator.validate(result)

        let dimDiags = diagnostics.filter { $0.code == "dimension.not-multiple-of-64" }
        #expect(dimDiags.count == 1, "Should have one dimension error")

        let diag = dimDiags[0]
        #expect(diag.fixIts.count == 2, "Should offer two choices")

        // Apply each fix-it and verify.
        for fixIt in diag.fixIts {
            let fixed = FixItApplicator.apply(fixIt, to: json)
            let fixedResult = Parser.parse(fixed)

            // Document still parses.
            #expect(fixedResult.errors.isEmpty, "Fixed document should parse: \(fixIt.label)")

            // The specific diagnostic is gone.
            let fixedDiags = Validator.validate(fixedResult)
            let remaining = fixedDiags.filter { $0.code == "dimension.not-multiple-of-64" }
            #expect(remaining.isEmpty,
                    "dimension.not-multiple-of-64 should be gone after \(fixIt.label)")

            // No new errors introduced.
            let newErrors = fixedDiags.filter { $0.severity == .error }
            #expect(newErrors.isEmpty,
                    "No new errors after \(fixIt.label), got: \(newErrors)")
        }
    }

    // MARK: - Applying any fix-it from fixtures

    @Test("Applying any fix-it yields a parseable document",
          arguments: ["DT_krea2_robo.json", "DT_krea2_robo_min.json",
                      "DT_wan2.2_i2v.json", "DT_Control_Example.json",
                      "DT_future_key.json"])
    func fixItProducesParseable(fixture: String) throws {
        let json = try loadFixture(fixture)
        let result = Parser.parse(json)
        let diagnostics = Validator.validate(result)

        for diag in diagnostics {
            for fixIt in diag.fixIts {
                let fixed = FixItApplicator.apply(fixIt, to: json)
                let fixedResult = Parser.parse(fixed)
                #expect(fixedResult.errors.isEmpty,
                        "\(fixture): fix-it '\(fixIt.label)' on \(diag.code) broke the document")
            }
        }
    }

    // MARK: - Empty-string → null fix-it

    @Test("Empty-string upscaler fix-it produces valid document")
    func emptyStringUpscalerFixIt() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "upscaler": "", "loras": [], "controls": []}
        """
        let result = Parser.parse(json)
        let diagnostics = Validator.validate(result)

        let upscalerDiag = diagnostics.first { $0.code == "value.upscaler-empty-string" }
        #expect(upscalerDiag != nil, "Should have upscaler warning")
        #expect(upscalerDiag?.fixIts.count == 1)

        let fixIt = upscalerDiag!.fixIts[0]
        let fixed = FixItApplicator.apply(fixIt, to: json)
        #expect(fixed.contains("null"))
        #expect(!fixed.contains("\"\""))

        // The warning should be gone.
        let fixedResult = Parser.parse(fixed)
        let fixedDiags = Validator.validate(fixedResult)
        let remaining = fixedDiags.filter { $0.code == "value.upscaler-empty-string" }
        #expect(remaining.isEmpty)
    }

    @Test("Empty-string refinerModel fix-it replaces with null")
    func emptyStringRefinerFixIt() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "refinerModel": "", "loras": [], "controls": []}
        """
        let result = Parser.parse(json)
        let diagnostics = Validator.validate(result)

        let diag = diagnostics.first { $0.code == "style.prefer-null" && $0.message.contains("refinerModel") }
        #expect(diag != nil)
        #expect(diag?.fixIts.count == 1)

        let fixed = FixItApplicator.apply(diag!.fixIts[0], to: json)
        let fixedResult = Parser.parse(fixed)
        #expect(fixedResult.errors.isEmpty)
        let fixedDiags = Validator.validate(fixedResult)
        let remaining = fixedDiags.filter { $0.code == "style.prefer-null" && $0.message.contains("refinerModel") }
        #expect(remaining.isEmpty)
    }

    // MARK: - Size changes

    @Test("Fix-it that changes size preserves surrounding content")
    func sizeChangingFixIt() {
        // "1000" (4 bytes) → "960" (3 bytes)
        let source = """
        {"width": 1000}
        """
        let fixIt = FixIt(range: 10..<14, replacement: "960", label: "Change to 960")
        let result = FixItApplicator.apply(fixIt, to: source)
        #expect(result == """
        {"width": 960}
        """)
    }

    // MARK: - Edge: empty range = insertion

    @Test("Empty range fix-it inserts at position")
    func insertionFixIt() {
        let source = "ab"
        let fixIt = FixIt(range: 1..<1, replacement: "X", label: "Insert X")
        let result = FixItApplicator.apply(fixIt, to: source)
        #expect(result == "aXb")
    }
}
