import Testing
import Foundation
import DTConfigCore
import DTConfigBridge
import DrawThingsClient

// MARK: - Fixture loading

private func fixtureURL(_ name: String) -> URL {
    let testsDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return testsDir.appendingPathComponent("Fixtures").appendingPathComponent(name)
}

private func loadFixture(_ name: String) throws -> String {
    try String(contentsOf: fixtureURL(name), encoding: .utf8)
}

/// JSON equality where 1, 1.0 and 1e0 are the same number.
private func sameJSON(_ a: JSONValue, _ b: JSONValue) -> Bool {
    switch (a, b) {
    case (.int(let x), .int(let y)), (.int(let x), .float(let y)),
         (.float(let x), .int(let y)), (.float(let x), .float(let y)):
        return Double(x) == Double(y)
    case (.array(let x), .array(let y)):
        return x.count == y.count && zip(x, y).allSatisfy(sameJSON)
    default:
        return a == b
    }
}

// MARK: - Conformance Tests

@Suite("Conformance")
struct ConformanceTests {
    static let fixtures = [
        "DT_krea2_robo.json",
        "DT_krea2_robo_min.json",
        "DT_wan2.2_i2v.json",
        "DT_Control_Example.json",
        "DT_future_key.json",
        "DT_h3_turbo_copy.json",
        "DT_h3_turbo_full.json",
        "DT_krea2_lora_copy.json",
        "DT_krea2_lora_full.json",
    ]

    @Test("configuration(from:) matches DrawThingsConfiguration.fromJSON", arguments: fixtures)
    func conformance(fixture: String) throws {
        let text = try loadFixture(fixture)
        let ours = ConfigurationInterop.configuration(from: text)
        let theirs = try DrawThingsConfiguration.fromJSON(text)
        #expect(ours == theirs, "Mismatch for \(fixture)")
    }

    @Test("Control extras survive decoding")
    func controlExtras() throws {
        let text = try loadFixture("DT_Control_Example.json")
        let control = try #require(ConfigurationInterop.configuration(from: text)?.controls.first)
        #expect(control.guidanceStart == 0.05)
        #expect(control.guidanceEnd == 0.9)
        #expect(control.globalAveragePooling == false)
    }

    @Test("A value of the wrong type is skipped, not fatal")
    func lenientDecoding() throws {
        let config = try #require(ConfigurationInterop.configuration(
            from: #"{"model": "m.ckpt", "steps": "twelve", "width": 768}"#))
        #expect(config.width == 768)
        #expect(config.steps == DrawThingsConfiguration().steps)
    }

    @Test("Legacy integer enums are read")
    func legacyIntegerEnums() throws {
        let config = try #require(ConfigurationInterop.configuration(from: """
            {"model": "m.ckpt", "compressionArtifacts": 3, "colorCalibration": 1,
             "controls": [{"file": "c.ckpt", "controlImportance": 2}]}
            """))
        #expect(config.compressionArtifacts == .jpeg)
        #expect(config.colorCalibration == .lab)
        #expect(config.controls.first?.controlMode == .control)
    }

    @Test("Missing or empty model is not a configuration")
    func modelRequired() {
        #expect(ConfigurationInterop.configuration(from: #"{"steps": 4}"#) == nil)
        #expect(ConfigurationInterop.configuration(from: #"{"model": ""}"#) == nil)
    }
}

// MARK: - Round-trip Tests

@Suite("Round-trip")
struct RoundTripTests {
    static let fixtures = [
        "DT_krea2_robo.json",
        "DT_wan2.2_i2v.json",
        "DT_Control_Example.json",
        "DT_future_key.json",
        "DT_h3_turbo_copy.json",
        "DT_h3_turbo_full.json",
        "DT_krea2_lora_copy.json",
        "DT_krea2_lora_full.json",
    ]

    @Test("struct round-trip preserves config equality", arguments: fixtures)
    func structRoundTrip(fixture: String) throws {
        let text = try loadFixture(fixture)
        let config1 = ConfigurationInterop.configuration(from: text)
        #expect(config1 != nil, "Failed to parse \(fixture)")
        guard let config1 else { return }

        // Determine original key set for .preserveShape
        let result = Parser.parse(text)
        guard let json = result.value, case .object(let pairs) = json else { return }
        let originalKeys = Set(pairs.map(\.key)).intersection(ConfigurationInterop.knownKeys)
        let unknownKeys = ConfigurationInterop.unknownKeys(from: result)

        let emitted = ConfigurationInterop.text(
            from: config1,
            style: .preserveShape(keys: originalKeys),
            unknownKeys: unknownKeys)
        let config2 = ConfigurationInterop.configuration(from: emitted)
        #expect(config2 == config1, "Round-trip failed for \(fixture)")
    }

    @Test(".nonDefaultOnly round-trips to an equal struct", arguments: fixtures)
    func nonDefaultOnlyRoundTrip(fixture: String) throws {
        let config1 = try #require(ConfigurationInterop.configuration(from: loadFixture(fixture)))
        let minimal = ConfigurationInterop.text(from: config1, style: .nonDefaultOnly)
        let config2 = ConfigurationInterop.configuration(from: minimal)
        #expect(config2 == config1, ".nonDefaultOnly round-trip produced different config")
    }

    @Test(".full round-trips to an equal struct", arguments: fixtures)
    func fullRoundTrip(fixture: String) throws {
        let config1 = try #require(ConfigurationInterop.configuration(from: loadFixture(fixture)))
        let full = ConfigurationInterop.text(from: config1, style: .full)
        #expect(ConfigurationInterop.configuration(from: full) == config1)
    }

    @Test("Control extras and new keys survive emission")
    func controlExtrasEmitted() throws {
        var config = DrawThingsConfiguration(model: "m.ckpt")
        config.controls = [ControlConfig(
            file: "c.ckpt", globalAveragePooling: true, noPrompt: true,
            downSamplingRate: 0.5, inputOverride: .depth, targetBlocks: ["a", "b"])]
        config.usesSolAttention = true
        config.shiftForAudio = 2
        let text = ConfigurationInterop.text(from: config, style: .nonDefaultOnly)
        #expect(text.contains("\"noPrompt\": true"))
        #expect(text.contains("\"inputOverride\": \"depth\""))
        #expect(text.contains("\"usesSolAttention\": true"))
        #expect(ConfigurationInterop.configuration(from: text) == config)
    }

    @Test("Random seed is written as -1 and omitted from .nonDefaultOnly")
    func randomSeed() throws {
        let config = DrawThingsConfiguration(model: "m.ckpt", seed: nil)
        #expect(ConfigurationInterop.text(from: config, style: .full).contains("\"seed\": -1"))
        #expect(!ConfigurationInterop.text(from: config, style: .nonDefaultOnly).contains("seed"))
        let parsed = try #require(ConfigurationInterop.configuration(from: #"{"model": "m.ckpt", "seed": -1}"#))
        #expect(parsed.seed == nil)
    }
}

// MARK: - Schema / client agreement

@Suite("Schema sync")
struct SchemaSyncTests {
    @Test("Every key DrawThingsClient writes is in the schema with a matching default")
    func schemaMatchesClientDefaults() {
        for (key, value) in ConfigurationInterop.defaultValues where key != "model" {
            let field = DrawThingsSchema.root.fields[key]
            #expect(field != nil, "Schema is missing \(key)")
            #expect(field?.jsonDefault.map { sameJSON($0, value) } == true, "Default for \(key): schema \(String(describing: field?.jsonDefault)), client \(value)")
        }
    }

    @Test("Every schema key is read by DrawThingsClient")
    func schemaHasNoStaleKeys() {
        for key in DrawThingsSchema.root.fields.keys {
            #expect(ConfigurationInterop.knownKeys.contains(key), "Schema key \(key) is not read by DrawThingsClient")
        }
    }

    @Test("Nested LoRA and control defaults match DrawThingsClient")
    func nestedDefaults() throws {
        let config = DrawThingsConfiguration(
            loras: [LoRAConfig(file: "l")], controls: [ControlConfig(file: "c")])
        let text = ConfigurationInterop.text(from: config, style: .full)
        guard case .object(let pairs)? = Parser.parse(text).value else {
            Issue.record("unparseable")
            return
        }
        let nested: [(String, ObjectSchema)] = [
            ("loras", DrawThingsSchema.loraSchema), ("controls", DrawThingsSchema.controlSchema),
        ]
        for (key, schema) in nested {
            guard case .array(let items)? = pairs.first(where: { $0.key == key })?.value,
                  case .object(let members)? = items.first
            else {
                Issue.record("\(key) missing")
                continue
            }
            for (member, value) in members where member != "file" {
                if member == "inputOverride" {
                    // DrawThingsClient 2.2 writes "unspecified"; the app writes "" (both decode the same).
                    #expect(value == .string("unspecified") || value == .string(""))
                    continue
                }
                #expect(schema.fields[member]?.jsonDefault.map { sameJSON($0, value) } == true, "\(key).\(member)")
            }
        }
    }
}

// MARK: - set(_:to:) Tests

@Suite("SurgicalEdit")
struct SurgicalEditTests {
    @Test("set changes only target key's bytes", arguments: [
        "DT_krea2_robo.json",
        "DT_wan2.2_i2v.json",
        "DT_Control_Example.json",
    ])
    @MainActor
    func surgicalEdit(fixture: String) throws {
        let text = try loadFixture(fixture)
        let result = Parser.parse(text)
        guard let json = result.value, case .object(let pairs) = json else {
            Issue.record("Failed to parse \(fixture)")
            return
        }

        let topLevelKeys = pairs.compactMap { pair -> String? in
            ConfigurationInterop.knownKeys.contains(pair.key) ? pair.key : nil
        }.filter { key in
            // Only test simple value keys (not arrays/objects)
            if let val = pairs.first(where: { $0.key == key })?.value {
                switch val {
                case .array, .object: return false
                default: return true
                }
            }
            return false
        }

        for key in topLevelKeys {
            let model = ConfigEditorModel(text: text)
            let originalBytes = Array(text.utf8)

            // Find original value byte range
            let parseResult = Parser.parse(text)
            guard let obj = findRootObject(parseResult.root) else { continue }
            var valueRange: Range<Int>?
            for member in obj.children
                where member.kind == .member && member.children.count >= 2
            {
                let keyNode = member.children[0]
                let valNode = member.children[1]
                guard let k = extractKey(keyNode, tokens: parseResult.tokens),
                      k == key else { continue }
                valueRange = valNode.byteRange
                break
            }
            guard let vr = valueRange else { continue }

            // Set to a new value
            model.set(key, to: .int("99999"))
            let newBytes = Array(model.text.utf8)

            // Bytes before the value range must be identical
            let prefixEnd = min(vr.lowerBound, originalBytes.count, newBytes.count)
            #expect(
                Array(originalBytes[0..<prefixEnd]) == Array(newBytes[0..<prefixEnd]),
                "Prefix changed for key \(key) in \(fixture)")

            // Bytes after the value range must be identical
            let newValueStr = "99999"
            let suffixStartOriginal = vr.upperBound
            let suffixStartNew = vr.lowerBound + newValueStr.utf8.count
            if suffixStartOriginal < originalBytes.count &&
                suffixStartNew < newBytes.count
            {
                let origSuffix = Array(originalBytes[suffixStartOriginal...])
                let newSuffix = Array(newBytes[suffixStartNew...])
                #expect(origSuffix == newSuffix,
                        "Suffix changed for key \(key) in \(fixture)")
            }
        }
    }

    // CST helpers for tests
    private func findRootObject(_ root: CSTNode) -> CSTNode? {
        for child in root.children where child.kind == .value {
            for gc in child.children where gc.kind == .object { return gc }
        }
        return nil
    }

    private func extractKey(_ node: CSTNode, tokens: [Token]) -> String? {
        for i in node.tokenRange where i < tokens.count {
            if tokens[i].kind == .string {
                let raw = tokens[i].text
                guard raw.count >= 2, raw.hasPrefix("\"") else { return raw }
                if raw.hasSuffix("\"") { return String(raw.dropFirst().dropLast()) }
                return String(raw.dropFirst())
            }
        }
        return nil
    }
}

// MARK: - Unknown/Future Key Tests

@Suite("UnknownKeys")
struct UnknownKeyTests {
    @Test("fabricated future key survives struct round-trip")
    func futureKeySurvival() throws {
        let text = try loadFixture("DT_future_key.json")
        let (config, unknownKeys) = ConfigurationInterop.configurationAndUnknownKeys(from: text)
        #expect(config != nil, "Failed to parse future key fixture")
        guard let config else { return }

        // The unknown key should be captured
        let futureKey = unknownKeys.first(where: { $0.0 == "futureFeatureFlag" })
        #expect(futureKey != nil, "futureFeatureFlag not in unknownKeys")
        #expect(futureKey?.1 == .bool(true))

        // Re-emit with unknown keys preserved
        let emitted = ConfigurationInterop.text(
            from: config, style: .full, unknownKeys: unknownKeys)

        // Parse again and verify
        let (config2, unknownKeys2) = ConfigurationInterop.configurationAndUnknownKeys(from: emitted)
        #expect(config2 == config, "Config changed after round-trip")
        let futureKey2 = unknownKeys2.first(where: { $0.0 == "futureFeatureFlag" })
        #expect(futureKey2 != nil, "futureFeatureFlag lost in round-trip")
        #expect(futureKey2?.1 == .bool(true))
    }
}

// MARK: - Model Family Inertness Tests

@Suite("ModelFamilyInertness")
struct ModelFamilyTests {
    @Test("krea image config marks video fields inert")
    func kreaInertFields() throws {
        let text = try loadFixture("DT_krea2_robo.json")
        let result = Parser.parse(text)
        let config = ConfigurationInterop.configuration(from: text)
        #expect(config != nil)

        let inert = ModelFamilyDetector.inertFields(forModel: config!.model)
        #expect(inert == ModelFamilyDetector.videoInertFields,
                "Krea (image model) should have all video fields inert")

        let diags = ModelFamilyDetector.inertDiagnostics(
            parseResult: result, modelName: config!.model)
        // The krea fixture contains fps, motionScale, guidingFrameNoise,
        // startFrameGuidance, numFrames, causalInference, causalInferencePad
        let inertKeys = Set(diags.map { d -> String in
            // Extract key name from diagnostic message
            let msg = d.message
            if let start = msg.firstIndex(of: "\""),
               let end = msg[msg.index(after: start)...].firstIndex(of: "\"") {
                return String(msg[msg.index(after: start)..<end])
            }
            return ""
        })
        let expectedInert: Set<String> = [
            "fps", "motionScale", "guidingFrameNoise", "startFrameGuidance",
            "numFrames", "causalInference", "causalInferencePad",
        ]
        #expect(inertKeys == expectedInert)
        #expect(diags.allSatisfy { $0.severity == .inert })
    }

    @Test("wan video config does NOT mark video fields inert")
    func wanNotInert() throws {
        let text = try loadFixture("DT_wan2.2_i2v.json")
        let config = ConfigurationInterop.configuration(from: text)
        #expect(config != nil)

        let inert = ModelFamilyDetector.inertFields(forModel: config!.model)
        #expect(inert.isEmpty,
                "Wan 2.2 (video model) should have no inert video fields")
    }

    @Test("model family detection")
    func familyDetection() {
        #expect(
            ModelFamilyDetector.detect(from: "krea_2_turbo_q8p.ckpt").nativeFrameRate == nil)
        #expect(
            ModelFamilyDetector.detect(from: "wan_v2.2_a14b_hne_i2v_q6p_svd.ckpt").nativeFrameRate != nil)
        #expect(
            ModelFamilyDetector.detect(from: "flux_1_dev_q8p.ckpt").nativeFrameRate == nil)
    }
}

// MARK: - Server Value Domain Provider Tests

@Suite("ServerValueDomainProvider")
struct ServerProviderTests {
    @Test("nil service degrades to free-form")
    func nilServiceDegrades() async {
        let provider = ServerValueDomainProvider(service: nil)
        let values = await provider.values(for: .model)
        #expect(values == nil)
    }

    @Test("checkFilesExist returns nil without service")
    func checkFilesNilService() async {
        let provider = ServerValueDomainProvider(service: nil)
        let result = await provider.checkFilesExist(["test.ckpt"])
        #expect(result == nil)
    }
}

// MARK: - ConfigEditorModel Tests

@Suite("ConfigEditorModel")
struct ConfigEditorModelTests {
    @Test("init from text produces valid configuration")
    @MainActor
    func initFromText() throws {
        let text = try loadFixture("DT_krea2_robo.json")
        let model = ConfigEditorModel(text: text)
        #expect(model.isValid)
        #expect(model.configuration != nil)
        #expect(model.configuration?.model == "krea_2_turbo_q8p.ckpt")
    }

    @Test("init from struct produces valid text")
    @MainActor
    func initFromStruct() {
        let config = DrawThingsConfiguration(model: "test.ckpt")
        let model = ConfigEditorModel(config)
        #expect(model.isValid)
        #expect(model.text.contains("test.ckpt"))
    }

    @Test("invalid text produces nil configuration")
    @MainActor
    func invalidText() {
        let model = ConfigEditorModel(text: "not json")
        #expect(!model.isValid)
        #expect(model.configuration == nil)
    }

    @Test("set updates text surgically")
    @MainActor
    func setUpdatesText() throws {
        let text = try loadFixture("DT_krea2_robo.json")
        let model = ConfigEditorModel(text: text)
        let originalText = model.text

        model.set("steps", to: .int("42"))

        #expect(model.text != originalText)
        #expect(model.text.contains("42"))
        // Original model name should still be present
        #expect(model.text.contains("krea_2_turbo_q8p.ckpt"))
    }

    @Test("Draw Things exports have no unknown keys")
    @MainActor
    func unknownKeysTracked() throws {
        let text = try loadFixture("DT_krea2_robo.json")
        let model = ConfigEditorModel(text: text)
        // "id" is written by Draw Things and known to DrawThingsClient
        #expect(model.unknownKeys.isEmpty)
    }

    @Test("set inserts a key with escaping")
    @MainActor
    func setEscapesInsertedKey() {
        let model = ConfigEditorModel(text: #"{"model": "m.ckpt"}"#)
        model.set(#"we"ird"#, to: .string("a\"b"))
        guard case .object(let pairs)? = Parser.parse(model.text).value else {
            Issue.record("Inserted key produced invalid JSON: \(model.text)")
            return
        }
        #expect(pairs.contains { $0.key == #"we"ird"# && $0.value == .string("a\"b") })
    }

    @Test("set replaces an existing value in place")
    @MainActor
    func setReplacesValue() {
        let model = ConfigEditorModel(text: #"{"model": "m.ckpt", "sampler": 0}"#)
        model.set("sampler", to: .int("200"))
        #expect(model.text == #"{"model": "m.ckpt", "sampler": 200}"#)
    }
}
