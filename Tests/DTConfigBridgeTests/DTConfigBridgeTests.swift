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

// MARK: - Reference parser (copied from client Examples/ConfigfromJSON.swift)

private func referenceConfigFromJSON(_ jsonString: String) -> DrawThingsConfiguration? {
    guard let data = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }

    guard let model = json["model"] as? String, !model.isEmpty else { return nil }

    let sampler: SamplerType
    if let si = json["sampler"] as? Int, let s = SamplerType(rawValue: Int8(si)) {
        sampler = s
    } else {
        sampler = .dpmpp2mkarras
    }
    let compressionArtifacts: CompressionMethod
    if let cs = json["compressionArtifacts"] as? String {
        switch cs.lowercased() {
        case "h264": compressionArtifacts = .h264
        case "h265": compressionArtifacts = .h265
        case "jpeg": compressionArtifacts = .jpeg
        default: compressionArtifacts = .disabled
        }
    } else if let ci = json["compressionArtifacts"] as? Int {
        compressionArtifacts = CompressionMethod(rawValue: Int8(ci)) ?? .disabled
    } else {
        compressionArtifacts = .disabled
    }

    var loras: [LoRAConfig] = []
    if let la = json["loras"] as? [[String: Any]] {
        for ld in la {
            if let file = ld["file"] as? String {
                let w = Float(ld["weight"] as? Double ?? 1.0)
                let mode: LoRAMode
                if let ms = ld["mode"] as? String {
                    switch ms.lowercased() {
                    case "base": mode = .base
                    case "refiner": mode = .refiner
                    default: mode = .all
                    }
                } else if let mi = ld["mode"] as? Int {
                    mode = LoRAMode(rawValue: Int8(mi)) ?? .all
                } else { mode = .all }
                loras.append(LoRAConfig(file: file, weight: w, mode: mode))
            }
        }
    }

    var controls: [ControlConfig] = []
    if let ca = json["controls"] as? [[String: Any]] {
        for cd in ca {
            if let file = cd["file"] as? String {
                let w = Float(cd["weight"] as? Double ?? 1.0)
                let gs = Float(cd["guidanceStart"] as? Double ?? 0.0)
                let ge = Float(cd["guidanceEnd"] as? Double ?? 1.0)
                let cm: ControlMode
                if let is_ = cd["controlImportance"] as? String {
                    switch is_.lowercased() {
                    case "prompt": cm = .prompt
                    case "control": cm = .control
                    default: cm = .balanced
                    }
                } else if let ii = cd["controlImportance"] as? Int {
                    cm = ControlMode(rawValue: Int8(ii)) ?? .balanced
                } else { cm = .balanced }
                controls.append(ControlConfig(file: file, weight: w, guidanceStart: gs, guidanceEnd: ge, controlMode: cm))
            }
        }
    }

    let refinerModel: String? = {
        guard let s = json["refinerModel"] as? String, !s.isEmpty else { return nil }
        return s
    }()
    let upscaler: String? = {
        guard let s = json["upscaler"] as? String, !s.isEmpty else { return nil }
        return s
    }()
    let faceRestoration: String? = {
        guard let s = json["faceRestoration"] as? String, !s.isEmpty else { return nil }
        return s
    }()

    return DrawThingsConfiguration(
        width: Int32(json["width"] as? Int ?? 1024),
        height: Int32(json["height"] as? Int ?? 1024),
        steps: Int32(json["steps"] as? Int ?? 20),
        model: model,
        sampler: sampler,
        guidanceScale: Float(json["guidanceScale"] as? Double ?? 7.0),
        seed: (json["seed"] as? Int).map { Int64($0) },
        clipSkip: Int32(json["clipSkip"] as? Int ?? 1),
        loras: loras,
        controls: controls,
        shift: Float(json["shift"] as? Double ?? 1.0),
        batchCount: Int32(json["batchCount"] as? Int ?? 1),
        batchSize: Int32(json["batchSize"] as? Int ?? 1),
        strength: Float(json["strength"] as? Double ?? 1.0),
        imageGuidanceScale: Float(json["imageGuidanceScale"] as? Double ?? 1.5),
        clipWeight: Float(json["clipWeight"] as? Double ?? 1.0),
        guidanceEmbed: Float(json["guidanceEmbed"] as? Double ?? 3.5),
        speedUpWithGuidanceEmbed: json["speedUpWithGuidanceEmbed"] as? Bool ?? true,
        cfgZeroStar: json["cfgZeroStar"] as? Bool ?? false,
        cfgZeroInitSteps: Int32(json["cfgZeroInitSteps"] as? Int ?? 0),
        compressionArtifacts: compressionArtifacts,
        compressionArtifactsQuality: Float(json["compressionArtifactsQuality"] as? Double ?? 43.1),
        maskBlur: Float(json["maskBlur"] as? Double ?? 1.5),
        maskBlurOutset: Int32(json["maskBlurOutset"] as? Int ?? 0),
        preserveOriginalAfterInpaint: json["preserveOriginalAfterInpaint"] as? Bool ?? true,
        sharpness: Float(json["sharpness"] as? Double ?? 0.0),
        stochasticSamplingGamma: Float(json["stochasticSamplingGamma"] as? Double ?? 0.3),
        aestheticScore: Float(json["aestheticScore"] as? Double ?? 6.0),
        negativeAestheticScore: Float(json["negativeAestheticScore"] as? Double ?? 2.5),
        negativePromptForImagePrior: json["negativePromptForImagePrior"] as? Bool ?? true,
        imagePriorSteps: Int32(json["imagePriorSteps"] as? Int ?? 5),
        cropTop: Int32(json["cropTop"] as? Int ?? 0),
        cropLeft: Int32(json["cropLeft"] as? Int ?? 0),
        originalImageHeight: Int32(json["originalImageHeight"] as? Int ?? 0),
        originalImageWidth: Int32(json["originalImageWidth"] as? Int ?? 0),
        targetImageHeight: Int32(json["targetImageHeight"] as? Int ?? 0),
        targetImageWidth: Int32(json["targetImageWidth"] as? Int ?? 0),
        negativeOriginalImageHeight: Int32(json["negativeOriginalImageHeight"] as? Int ?? 0),
        negativeOriginalImageWidth: Int32(json["negativeOriginalImageWidth"] as? Int ?? 0),
        upscalerScaleFactor: Int32(json["upscalerScaleFactor"] as? Int ?? 0),
        resolutionDependentShift: json["resolutionDependentShift"] as? Bool ?? false,
        t5TextEncoder: json["t5TextEncoder"] as? Bool ?? true,
        separateClipL: json["separateClipL"] as? Bool ?? false,
        separateOpenClipG: json["separateOpenClipG"] as? Bool ?? false,
        separateT5: json["separateT5"] as? Bool ?? false,
        tiledDiffusion: json["tiledDiffusion"] as? Bool ?? false,
        diffusionTileWidth: Int32(json["diffusionTileWidth"] as? Int ?? 1024),
        diffusionTileHeight: Int32(json["diffusionTileHeight"] as? Int ?? 1024),
        diffusionTileOverlap: Int32(json["diffusionTileOverlap"] as? Int ?? 128),
        tiledDecoding: json["tiledDecoding"] as? Bool ?? false,
        decodingTileWidth: Int32(json["decodingTileWidth"] as? Int ?? 640),
        decodingTileHeight: Int32(json["decodingTileHeight"] as? Int ?? 640),
        decodingTileOverlap: Int32(json["decodingTileOverlap"] as? Int ?? 128),
        hiresFix: json["hiresFix"] as? Bool ?? false,
        hiresFixWidth: Int32(json["hiresFixWidth"] as? Int ?? 1024),
        hiresFixHeight: Int32(json["hiresFixHeight"] as? Int ?? 1024),
        hiresFixStrength: Float(json["hiresFixStrength"] as? Double ?? 0.7),
        stage2Steps: Int32(json["stage2Steps"] as? Int ?? 10),
        stage2Guidance: Float(json["stage2Guidance"] as? Double ?? 1.0),
        stage2Shift: Float(json["stage2Shift"] as? Double ?? 1.0),
        teaCache: json["teaCache"] as? Bool ?? false,
        teaCacheStart: Int32(json["teaCacheStart"] as? Int ?? 5),
        teaCacheEnd: Int32(json["teaCacheEnd"] as? Int ?? -1),
        teaCacheThreshold: Float(json["teaCacheThreshold"] as? Double ?? 0.2),
        teaCacheMaxSkipSteps: Int32(json["teaCacheMaxSkipSteps"] as? Int ?? 3),
        causalInferenceEnabled: json["causalInferenceEnabled"] as? Bool ?? false,
        causalInference: Int32(json["causalInference"] as? Int ?? 0),
        causalInferencePad: Int32(json["causalInferencePad"] as? Int ?? 0),
        fps: Int32(json["fps"] as? Int ?? 5),
        motionScale: Int32(json["motionScale"] as? Int ?? 127),
        guidingFrameNoise: Float(json["guidingFrameNoise"] as? Double ?? 0.02),
        startFrameGuidance: Float(json["startFrameGuidance"] as? Double ?? 1.0),
        numFrames: Int32(json["numFrames"] as? Int ?? 14),
        refinerModel: refinerModel,
        refinerStart: Float(json["refinerStart"] as? Double ?? 0.85),
        zeroNegativePrompt: json["zeroNegativePrompt"] as? Bool ?? false,
        upscaler: upscaler,
        faceRestoration: faceRestoration,
        clipLText: json["clipLText"] as? String,
        openClipGText: json["openClipGText"] as? String,
        seedMode: Int32(json["seedMode"] as? Int ?? 2)
    )
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
    ]

    @Test("configuration(from:) matches client parser", arguments: fixtures)
    func conformance(fixture: String) throws {
        let text = try loadFixture(fixture)
        let ours = ConfigurationInterop.configuration(from: text)
        let theirs = referenceConfigFromJSON(text)
        #expect(ours == theirs, "Mismatch for \(fixture)")
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

    @Test(".nonDefaultOnly on krea export round-trips to equal struct")
    func nonDefaultOnlyRoundTrip() throws {
        let text = try loadFixture("DT_krea2_robo.json")
        let config1 = ConfigurationInterop.configuration(from: text)
        #expect(config1 != nil)
        guard let config1 else { return }

        let minimal = ConfigurationInterop.text(from: config1, style: .nonDefaultOnly)
        let config2 = ConfigurationInterop.configuration(from: minimal)
        #expect(config2 == config1,
                ".nonDefaultOnly round-trip produced different config")
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

    @Test("unknown keys tracked from text init")
    @MainActor
    func unknownKeysTracked() throws {
        let text = try loadFixture("DT_krea2_robo.json")
        let model = ConfigEditorModel(text: text)
        // krea fixture has "id": 0 which is not a known key
        let hasId = model.unknownKeys.contains(where: { $0.0 == "id" })
        #expect(hasId, "id should be in unknownKeys")
    }
}
