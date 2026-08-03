import Testing
import DTConfigCore
import Foundation

@Suite("Validator Tests")
struct ValidatorTests {

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

    // MARK: - Fixture: zero errors

    @Test("krea2_robo: zero errors")
    func krea2RoboZeroErrors() throws {
        let diagnostics = try validateFixture("DT_krea2_robo.json")
        let errors = diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty, "Expected zero errors, got: \(errors)")
    }

    @Test("krea2_robo_min: zero errors")
    func krea2RoboMinZeroErrors() throws {
        let diagnostics = try validateFixture("DT_krea2_robo_min.json")
        let errors = diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty, "Expected zero errors, got: \(errors)")
    }

    @Test("wan2.2_i2v: zero errors")
    func wan22ZeroErrors() throws {
        let diagnostics = try validateFixture("DT_wan2.2_i2v.json")
        let errors = diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty, "Expected zero errors, got: \(errors)")
    }

    @Test("Control_Example: zero errors")
    func controlExampleZeroErrors() throws {
        let diagnostics = try validateFixture("DT_Control_Example.json")
        let errors = diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty, "Expected zero errors, got: \(errors)")
    }

    @Test("future_key: zero errors")
    func futureKeyZeroErrors() throws {
        let diagnostics = try validateFixture("DT_future_key.json")
        let errors = diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty, "Expected zero errors, got: \(errors)")
    }

    // MARK: - Fixture: expected warnings

    @Test("krea2_robo: unknown key 'id' warning")
    func krea2RoboWarnings() throws {
        let diagnostics = try validateFixture("DT_krea2_robo.json")
        let warnings = diagnostics.filter { $0.severity == .warning }
        let unknownKeys = warnings.filter { $0.code == "unknown-key" }
        #expect(unknownKeys.count == 1)
        #expect(unknownKeys.first?.message.contains("id") == true)
    }

    @Test("krea2_robo_min: empty upscaler warning")
    func krea2RoboMinWarnings() throws {
        let diagnostics = try validateFixture("DT_krea2_robo_min.json")
        let warnings = diagnostics.filter { $0.severity == .warning }
        let upscalerWarnings = warnings.filter { $0.code == "value.upscaler-empty-string" }
        #expect(upscalerWarnings.count == 1)
    }

    @Test("wan2.2_i2v: unknown 'id' + hiresFix warnings")
    func wan22Warnings() throws {
        let diagnostics = try validateFixture("DT_wan2.2_i2v.json")
        let warnings = diagnostics.filter { $0.severity == .warning }

        let unknownKeys = warnings.filter { $0.code == "unknown-key" }
        #expect(unknownKeys.count == 1)
        #expect(unknownKeys.first?.message.contains("id") == true)

        let hiresWarnings = warnings.filter { $0.code == "cross-field.hires-fix-disabled" }
        #expect(hiresWarnings.count == 2)
    }

    @Test("Control_Example: unknown 'id' + hiresFix + teaCache warnings")
    func controlExampleWarnings() throws {
        let diagnostics = try validateFixture("DT_Control_Example.json")
        let warnings = diagnostics.filter { $0.severity == .warning }

        let unknownKeys = warnings.filter { $0.code == "unknown-key" }
        #expect(unknownKeys.count == 1)
        #expect(unknownKeys.first?.message.contains("id") == true)

        let hiresWarnings = warnings.filter { $0.code == "cross-field.hires-fix-disabled" }
        #expect(hiresWarnings.count == 2)

        let teaCacheWarnings = warnings.filter { $0.code == "cross-field.tea-cache-disabled" }
        #expect(teaCacheWarnings.count == 1)
        #expect(teaCacheWarnings.first?.message.contains("teaCacheThreshold") == true)
    }

    @Test("future_key: unknown key warning for futureFeatureFlag")
    func futureKeyWarnings() throws {
        let diagnostics = try validateFixture("DT_future_key.json")
        let warnings = diagnostics.filter { $0.severity == .warning }
        #expect(warnings.count == 1)
        #expect(warnings.first?.code == "unknown-key")
        #expect(warnings.first?.message.contains("futureFeatureFlag") == true)
    }

    // MARK: - Future key survives edit

    @Test("Future key survives parse round-trip and edit")
    func futureKeySurvivesEdit() throws {
        let json = try loadFixture("DT_future_key.json")
        let result = Parser.parse(json)

        // Round-trip preserves source
        #expect(result.description == json)

        // Future key present in extracted value
        guard case .object(let pairs) = result.valueRecovered else {
            Issue.record("Expected object")
            return
        }
        let futureKey = pairs.first(where: { $0.key == "futureFeatureFlag" })
        #expect(futureKey != nil)
        #expect(futureKey?.value == .bool(true))

        // Simulate edit: change width from 1024 to 1280
        let edited = json.replacingOccurrences(of: "\"width\": 1024", with: "\"width\": 1280")
        let result2 = Parser.parse(edited)
        guard case .object(let pairs2) = result2.valueRecovered else {
            Issue.record("Expected object after edit")
            return
        }
        let futureKey2 = pairs2.first(where: { $0.key == "futureFeatureFlag" })
        #expect(futureKey2 != nil, "Future key must survive edit")
        #expect(futureKey2?.value == .bool(true))
    }

    // MARK: - Type mismatch

    @Test("Type mismatch: string where int expected")
    func typeMismatchStringForInt() {
        let json = """
        {"model": "test.ckpt", "width": "big", "height": 1024, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let mismatches = diagnostics.filter { $0.code == "type.mismatch" }
        #expect(mismatches.count == 1)
        #expect(mismatches[0].message.contains("width"))
    }

    @Test("Type mismatch: int where bool expected")
    func typeMismatchIntForBool() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "hiresFix": 1, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let mismatches = diagnostics.filter { $0.code == "type.mismatch" }
        #expect(mismatches.count == 1)
        #expect(mismatches[0].message.contains("hiresFix"))
    }

    // MARK: - Multiple of 64

    @Test("Width not multiple of 64 produces error with two fix-its")
    func multipleOf64Error() {
        let json = """
        {"model": "test.ckpt", "width": 1000, "height": 1024, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let dimErrors = diagnostics.filter { $0.code == "dimension.not-multiple-of-64" }
        #expect(dimErrors.count == 1)
        #expect(dimErrors[0].severity == .error)
        #expect(dimErrors[0].fixIts.count == 2)
        #expect(dimErrors[0].fixIts[0].replacement == "960")
        #expect(dimErrors[0].fixIts[1].replacement == "1024")
    }

    @Test("Width of 0 passes multipleOf64 (valid sentinel)")
    func zeroPassesMultipleOf64() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "hiresFixWidth": 0, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let dimErrors = diagnostics.filter { $0.code == "dimension.not-multiple-of-64" }
        #expect(dimErrors.isEmpty)
    }

    // MARK: - Enum validation

    @Test("Invalid sampler value produces error")
    func invalidSampler() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "sampler": 99, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let enumErrors = diagnostics.filter { $0.code == "enum.out-of-range" }
        #expect(enumErrors.count == 1)
        #expect(enumErrors[0].message.contains("SamplerType"))
    }

    @Test("Valid sampler values accepted")
    func validSampler() {
        for i in 0...19 {
            let json = """
            {"model": "test.ckpt", "width": 1024, "height": 1024, "sampler": \(i), "loras": [], "controls": []}
            """
            let diagnostics = validate(json)
            let enumErrors = diagnostics.filter { $0.code == "enum.out-of-range" }
            #expect(enumErrors.isEmpty, "Sampler \(i) should be valid")
        }
    }

    @Test("Invalid compressionArtifacts string produces error")
    func invalidCompressionString() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "compressionArtifacts": "webp", "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let enumErrors = diagnostics.filter { $0.code == "enum.invalid-value" }
        #expect(enumErrors.count == 1)
    }

    @Test("compressionArtifacts accepts both string and int forms")
    func compressionBothForms() {
        let jsonStr = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "compressionArtifacts": "jpeg", "loras": [], "controls": []}
        """
        let jsonInt = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "compressionArtifacts": 3, "loras": [], "controls": []}
        """
        let d1 = validate(jsonStr).filter { $0.severity == .error }
        let d2 = validate(jsonInt).filter { $0.severity == .error }
        #expect(d1.isEmpty)
        #expect(d2.isEmpty)
    }

    // MARK: - Unknown keys

    @Test("Unknown key produces warning, not error")
    func unknownKeyWarning() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "unknownFuture": 42, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let unknown = diagnostics.filter { $0.code == "unknown-key" }
        #expect(unknown.count == 1)
        #expect(unknown[0].severity == .warning)
        #expect(unknown[0].message.contains("unknownFuture"))
    }

    // MARK: - Cross-field rules

    @Test("LoRA mode 'refiner' with no refinerModel warns")
    func loraRefinerNoModel() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "refinerModel": null, "loras": [{"file": "a.ckpt", "weight": 1, "mode": "refiner"}], "controls": []}
        """
        let diagnostics = validate(json)
        let warnings = diagnostics.filter { $0.code == "cross-field.lora-refiner-no-model" }
        #expect(warnings.count == 1)
    }

    @Test("LoRA mode 'refiner' with refinerModel set does not warn")
    func loraRefinerWithModel() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "refinerModel": "ref.ckpt", "loras": [{"file": "a.ckpt", "weight": 1, "mode": "refiner"}], "controls": []}
        """
        let diagnostics = validate(json)
        let warnings = diagnostics.filter { $0.code == "cross-field.lora-refiner-no-model" }
        #expect(warnings.isEmpty)
    }

    @Test("refinerStart non-default without refinerModel warns")
    func refinerStartNoModel() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "refinerStart": 0.5, "refinerModel": null, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let warnings = diagnostics.filter { $0.code == "cross-field.refiner-start-no-model" }
        #expect(warnings.count == 1)
    }

    @Test("refinerStart at default without refinerModel does not warn")
    func refinerStartDefaultNoModel() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "refinerStart": 0.85, "refinerModel": null, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let warnings = diagnostics.filter { $0.code == "cross-field.refiner-start-no-model" }
        #expect(warnings.isEmpty)
    }

    @Test("clipLText non-null with separateClipL false warns")
    func clipLTextIgnored() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "clipLText": "hello", "separateClipL": false, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let warnings = diagnostics.filter { $0.code == "cross-field.clip-l-text-ignored" }
        #expect(warnings.count == 1)
    }

    @Test("Empty string upscaler warns")
    func emptyUpscalerWarns() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "upscaler": "", "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let warnings = diagnostics.filter { $0.code == "value.upscaler-empty-string" }
        #expect(warnings.count == 1)
    }

    @Test("Null upscaler does not warn")
    func nullUpscalerOk() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "upscaler": null, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let warnings = diagnostics.filter { $0.code == "value.upscaler-empty-string" }
        #expect(warnings.isEmpty)
    }

    @Test("seed -1 is valid (sentinel)")
    func seedSentinel() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "seed": -1, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let errors = diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty)
    }

    @Test("seed null is valid")
    func seedNull() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "seed": null, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let errors = diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty)
    }

    @Test("teaCacheEnd -1 is valid (sentinel)")
    func teaCacheEndSentinel() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "teaCacheEnd": -1, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let errors = diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty)
    }

    // MARK: - Required model

    @Test("Missing model key produces error")
    func missingModel() {
        let json = """
        {"width": 1024, "height": 1024, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let modelErrors = diagnostics.filter { $0.code == "required.model" }
        #expect(modelErrors.count == 1)
        #expect(modelErrors[0].severity == .error)
    }

    @Test("Empty model produces error")
    func emptyModel() {
        let json = """
        {"model": "", "width": 1024, "height": 1024, "loras": [], "controls": []}
        """
        let diagnostics = validate(json)
        let modelErrors = diagnostics.filter { $0.code == "value.model-empty" }
        #expect(modelErrors.count == 1)
    }

    // MARK: - Nested array validation

    @Test("LoRA missing file warns")
    func loraMissingFile() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "loras": [{"weight": 1, "mode": "all"}], "controls": []}
        """
        let diagnostics = validate(json)
        let warnings = diagnostics.filter { $0.code == "value.missing-file" }
        #expect(warnings.count == 1)
    }

    @Test("LoRA empty file warns")
    func loraEmptyFile() {
        let json = """
        {"model": "test.ckpt", "width": 1024, "height": 1024, "loras": [{"file": "", "weight": 1, "mode": "all"}], "controls": []}
        """
        let diagnostics = validate(json)
        let warnings = diagnostics.filter { $0.code == "value.empty-file" }
        #expect(warnings.count == 1)
    }

    // MARK: - Diagnostic Codable

    @Test("Diagnostic round-trips through Codable")
    func diagnosticCodable() throws {
        let diag = Diagnostic(
            range: 10..<20,
            severity: .warning,
            code: "test.code",
            message: "Test message",
            fixIts: [
                FixIt(range: 12..<15, replacement: "fix", label: "Apply fix")
            ])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(diag)
        let decoded = try JSONDecoder().decode(Diagnostic.self, from: data)
        #expect(decoded == diag)
    }

    // MARK: - Expected diagnostics files

    @Test("Fixture diagnostics match .expected.json",
          arguments: ["DT_krea2_robo", "DT_krea2_robo_min", "DT_wan2.2_i2v", "DT_Control_Example", "DT_future_key"])
    func expectedDiagnosticsMatch(name: String) throws {
        let json = try loadFixture("\(name).json")
        let result = Parser.parse(json)
        let diagnostics = Validator.validate(result)

        let expectedURL = fixturesURL().appendingPathComponent("\(name).expected.json")
        let data = try Data(contentsOf: expectedURL)
        let expected = try JSONDecoder().decode([Diagnostic].self, from: data)

        #expect(diagnostics.count == expected.count,
                "Diagnostic count mismatch for \(name): got \(diagnostics.count), expected \(expected.count)")
        for (actual, exp) in zip(diagnostics, expected) {
            #expect(actual == exp,
                    "Diagnostic mismatch for \(name):\n  got:      \(actual)\n  expected: \(exp)")
        }
    }

    // MARK: - Non-object root

    @Test("Non-object root produces error")
    func nonObjectRoot() {
        let json = "[1, 2, 3]"
        let diagnostics = validate(json)
        let errors = diagnostics.filter { $0.code == "type.expected-object" }
        #expect(errors.count == 1)
    }

    // MARK: - Helpers

    private func validate(_ json: String) -> [Diagnostic] {
        let result = Parser.parse(json)
        return Validator.validate(result)
    }

    private func validateFixture(_ name: String) throws -> [Diagnostic] {
        let json = try loadFixture(name)
        let result = Parser.parse(json)
        return Validator.validate(result)
    }
}
