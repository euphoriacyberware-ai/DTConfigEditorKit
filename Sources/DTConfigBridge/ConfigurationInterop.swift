import DTConfigCore
import DrawThingsClient

public enum EmitStyle: Sendable {
    case full
    case nonDefaultOnly
    case preserveShape(keys: Set<String>)
}

public enum ConfigurationInterop {

    // MARK: - Parse (text -> struct)

    public static func configuration(from text: String) -> DrawThingsConfiguration? {
        let result = Parser.parse(text)
        return configuration(from: result)
    }

    public static func configuration(from result: ParseResult) -> DrawThingsConfiguration? {
        guard let json = result.value else { return nil }
        return configuration(from: json)
    }

    public static func configuration(from json: JSONValue) -> DrawThingsConfiguration? {
        guard case .object(let pairs) = json else { return nil }
        let dict = Dictionary(pairs.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })
        return configFromDict(dict)
    }

    public static func unknownKeys(from text: String) -> [(String, JSONValue)] {
        let result = Parser.parse(text)
        return unknownKeys(from: result)
    }

    public static func unknownKeys(from result: ParseResult) -> [(String, JSONValue)] {
        guard let json = result.value ?? result.valueRecovered,
              case .object(let pairs) = json else { return [] }
        return pairs.filter { !knownKeys.contains($0.key) }
    }

    public static func configurationAndUnknownKeys(
        from text: String
    ) -> (DrawThingsConfiguration?, [(String, JSONValue)]) {
        let result = Parser.parse(text)
        return configurationAndUnknownKeys(from: result)
    }

    public static func configurationAndUnknownKeys(
        from result: ParseResult
    ) -> (DrawThingsConfiguration?, [(String, JSONValue)]) {
        guard let json = result.value else {
            let unknown = unknownKeys(from: result)
            return (nil, unknown)
        }
        guard case .object(let pairs) = json else { return (nil, []) }
        let dict = Dictionary(pairs.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })
        let config = configFromDict(dict)
        let unknown = pairs.filter { !knownKeys.contains($0.key) }
        return (config, unknown)
    }

    // MARK: - Emit (struct -> text)

    public static func text(
        from config: DrawThingsConfiguration,
        style: EmitStyle = .nonDefaultOnly,
        unknownKeys: [(String, JSONValue)] = []
    ) -> String {
        var pairs = configToKeyValues(config)

        switch style {
        case .full:
            break
        case .nonDefaultOnly:
            pairs = pairs.filter { key, value in
                if key == "model" { return true }
                guard let defaultValue = jsonParserDefaults[key] else { return true }
                return !numericEqual(value, defaultValue)
            }
        case .preserveShape(let keys):
            pairs = pairs.filter { keys.contains($0.0) }
            if !pairs.contains(where: { $0.0 == "model" }) {
                pairs.insert(("model", .string(config.model)), at: 0)
            }
        }

        for (key, value) in unknownKeys {
            if !pairs.contains(where: { $0.0 == key }) {
                pairs.append((key, value))
            }
        }

        pairs.sort { $0.0 < $1.0 }
        return emitJSON(pairs)
    }

    // MARK: - Known keys (matches configurationFromJSON's parsed keys)

    public static let knownKeys: Set<String> = [
        "model", "width", "height", "steps", "sampler", "guidanceScale", "seed",
        "clipSkip", "shift", "batchCount", "batchSize", "strength",
        "imageGuidanceScale", "clipWeight", "guidanceEmbed",
        "speedUpWithGuidanceEmbed", "cfgZeroStar", "cfgZeroInitSteps",
        "compressionArtifacts", "compressionArtifactsQuality", "colorCalibration",
        "maskBlur", "maskBlurOutset", "preserveOriginalAfterInpaint",
        "sharpness", "stochasticSamplingGamma", "aestheticScore",
        "negativeAestheticScore", "negativePromptForImagePrior", "imagePriorSteps",
        "cropTop", "cropLeft", "originalImageHeight", "originalImageWidth",
        "targetImageHeight", "targetImageWidth",
        "negativeOriginalImageHeight", "negativeOriginalImageWidth",
        "upscalerScaleFactor", "resolutionDependentShift", "t5TextEncoder",
        "separateClipL", "separateOpenClipG", "separateT5",
        "tiledDiffusion", "diffusionTileWidth", "diffusionTileHeight",
        "diffusionTileOverlap", "tiledDecoding", "decodingTileWidth",
        "decodingTileHeight", "decodingTileOverlap",
        "hiresFix", "hiresFixWidth", "hiresFixHeight", "hiresFixStrength",
        "stage2Steps", "stage2Guidance", "stage2Shift",
        "teaCache", "teaCacheStart", "teaCacheEnd", "teaCacheThreshold",
        "teaCacheMaxSkipSteps", "causalInferenceEnabled", "causalInference",
        "causalInferencePad", "fps", "motionScale", "guidingFrameNoise",
        "startFrameGuidance", "numFrames", "refinerModel", "refinerStart",
        "zeroNegativePrompt", "upscaler", "faceRestoration",
        "enableInpainting",
        "name",
        "clipLText", "openClipGText", "t5Text", "seedMode",
        "loras", "controls",
    ]

    // MARK: - JSON parser defaults (authoritative for .nonDefaultOnly)

    private static let jsonParserDefaults: [String: JSONValue] = {
        var defaults: [String: JSONValue] = [:]
        for (key, schema) in DrawThingsSchema.root.fields {
            if let d = schema.jsonDefault { defaults[key] = d }
        }
        return defaults
    }()

    // MARK: - Dict -> Config

    private static func configFromDict(_ d: [String: JSONValue]) -> DrawThingsConfiguration? {
        guard let model = d["model"]?.asString, !model.isEmpty else { return nil }

        let sampler: SamplerType
        if let raw = d["sampler"]?.asInt32,
           let raw8 = Int8(exactly: raw),
           let s = SamplerType(rawValue: raw8) {
            sampler = s
        } else {
            sampler = .dpmpp2mkarras
        }

        let compressionArtifacts: CompressionMethod
        if let s = d["compressionArtifacts"]?.asString {
            compressionArtifacts = mapCompressionString(s)
        } else if let i = d["compressionArtifacts"]?.asInt32,
                  let i8 = Int8(exactly: i) {
            compressionArtifacts = CompressionMethod(rawValue: i8) ?? .disabled
        } else {
            compressionArtifacts = .disabled
        }

        let colorCalibration: ColorCalibration
        if let s = d["colorCalibration"]?.asString {
            colorCalibration = mapColorCalibrationString(s)
        } else if let i = d["colorCalibration"]?.asInt32,
                  let i8 = Int8(exactly: i) {
            colorCalibration = ColorCalibration(rawValue: i8) ?? .disabled
        } else {
            colorCalibration = .disabled
        }

        let loras = parseLoras(d["loras"])
        let controls = parseControls(d["controls"])

        let refinerModel = coalesceEmpty(d["refinerModel"])
        let upscaler = coalesceEmpty(d["upscaler"])
        let faceRestoration = coalesceEmpty(d["faceRestoration"])

        return DrawThingsConfiguration(
            width: d["width"]?.asInt32 ?? 1024,
            height: d["height"]?.asInt32 ?? 1024,
            steps: d["steps"]?.asInt32 ?? 20,
            model: model,
            sampler: sampler,
            guidanceScale: d["guidanceScale"]?.asFloat ?? 7.0,
            seed: d["seed"]?.asInt64,
            clipSkip: d["clipSkip"]?.asInt32 ?? 1,
            loras: loras,
            controls: controls,
            shift: d["shift"]?.asFloat ?? 1.0,
            batchCount: d["batchCount"]?.asInt32 ?? 1,
            batchSize: d["batchSize"]?.asInt32 ?? 1,
            strength: d["strength"]?.asFloat ?? 1.0,
            imageGuidanceScale: d["imageGuidanceScale"]?.asFloat ?? 1.5,
            clipWeight: d["clipWeight"]?.asFloat ?? 1.0,
            guidanceEmbed: d["guidanceEmbed"]?.asFloat ?? 3.5,
            speedUpWithGuidanceEmbed: d["speedUpWithGuidanceEmbed"]?.asBool ?? true,
            cfgZeroStar: d["cfgZeroStar"]?.asBool ?? false,
            cfgZeroInitSteps: d["cfgZeroInitSteps"]?.asInt32 ?? 0,
            compressionArtifacts: compressionArtifacts,
            compressionArtifactsQuality: d["compressionArtifactsQuality"]?.asFloat ?? 43.1,
            colorCalibration: colorCalibration,
            maskBlur: d["maskBlur"]?.asFloat ?? 1.5,
            maskBlurOutset: d["maskBlurOutset"]?.asInt32 ?? 0,
            preserveOriginalAfterInpaint: d["preserveOriginalAfterInpaint"]?.asBool ?? true,
            enableInpainting: d["enableInpainting"]?.asBool ?? false,
            sharpness: d["sharpness"]?.asFloat ?? 0.0,
            stochasticSamplingGamma: d["stochasticSamplingGamma"]?.asFloat ?? 0.3,
            aestheticScore: d["aestheticScore"]?.asFloat ?? 6.0,
            negativeAestheticScore: d["negativeAestheticScore"]?.asFloat ?? 2.5,
            negativePromptForImagePrior: d["negativePromptForImagePrior"]?.asBool ?? true,
            imagePriorSteps: d["imagePriorSteps"]?.asInt32 ?? 5,
            cropTop: d["cropTop"]?.asInt32 ?? 0,
            cropLeft: d["cropLeft"]?.asInt32 ?? 0,
            originalImageHeight: d["originalImageHeight"]?.asInt32 ?? 0,
            originalImageWidth: d["originalImageWidth"]?.asInt32 ?? 0,
            targetImageHeight: d["targetImageHeight"]?.asInt32 ?? 0,
            targetImageWidth: d["targetImageWidth"]?.asInt32 ?? 0,
            negativeOriginalImageHeight: d["negativeOriginalImageHeight"]?.asInt32 ?? 0,
            negativeOriginalImageWidth: d["negativeOriginalImageWidth"]?.asInt32 ?? 0,
            upscalerScaleFactor: d["upscalerScaleFactor"]?.asInt32 ?? 0,
            resolutionDependentShift: d["resolutionDependentShift"]?.asBool ?? false,
            t5TextEncoder: d["t5TextEncoder"]?.asBool ?? true,
            separateClipL: d["separateClipL"]?.asBool ?? false,
            separateOpenClipG: d["separateOpenClipG"]?.asBool ?? false,
            separateT5: d["separateT5"]?.asBool ?? false,
            tiledDiffusion: d["tiledDiffusion"]?.asBool ?? false,
            diffusionTileWidth: d["diffusionTileWidth"]?.asInt32 ?? 1024,
            diffusionTileHeight: d["diffusionTileHeight"]?.asInt32 ?? 1024,
            diffusionTileOverlap: d["diffusionTileOverlap"]?.asInt32 ?? 128,
            tiledDecoding: d["tiledDecoding"]?.asBool ?? false,
            decodingTileWidth: d["decodingTileWidth"]?.asInt32 ?? 640,
            decodingTileHeight: d["decodingTileHeight"]?.asInt32 ?? 640,
            decodingTileOverlap: d["decodingTileOverlap"]?.asInt32 ?? 128,
            hiresFix: d["hiresFix"]?.asBool ?? false,
            hiresFixWidth: d["hiresFixWidth"]?.asInt32 ?? 1024,
            hiresFixHeight: d["hiresFixHeight"]?.asInt32 ?? 1024,
            hiresFixStrength: d["hiresFixStrength"]?.asFloat ?? 0.7,
            stage2Steps: d["stage2Steps"]?.asInt32 ?? 10,
            stage2Guidance: d["stage2Guidance"]?.asFloat ?? 1.0,
            stage2Shift: d["stage2Shift"]?.asFloat ?? 1.0,
            teaCache: d["teaCache"]?.asBool ?? false,
            teaCacheStart: d["teaCacheStart"]?.asInt32 ?? 5,
            teaCacheEnd: d["teaCacheEnd"]?.asInt32 ?? -1,
            teaCacheThreshold: d["teaCacheThreshold"]?.asFloat ?? 0.2,
            teaCacheMaxSkipSteps: d["teaCacheMaxSkipSteps"]?.asInt32 ?? 3,
            causalInferenceEnabled: d["causalInferenceEnabled"]?.asBool ?? false,
            causalInference: d["causalInference"]?.asInt32 ?? 0,
            causalInferencePad: d["causalInferencePad"]?.asInt32 ?? 0,
            fps: d["fps"]?.asInt32 ?? 5,
            motionScale: d["motionScale"]?.asInt32 ?? 127,
            guidingFrameNoise: d["guidingFrameNoise"]?.asFloat ?? 0.02,
            startFrameGuidance: d["startFrameGuidance"]?.asFloat ?? 1.0,
            numFrames: d["numFrames"]?.asInt32 ?? 14,
            refinerModel: refinerModel,
            refinerStart: d["refinerStart"]?.asFloat ?? 0.85,
            zeroNegativePrompt: d["zeroNegativePrompt"]?.asBool ?? false,
            upscaler: upscaler,
            faceRestoration: faceRestoration,
            name: d["name"]?.asOptionalString,
            clipLText: d["clipLText"]?.asOptionalString,
            openClipGText: d["openClipGText"]?.asOptionalString,
            t5Text: d["t5Text"]?.asOptionalString,
            seedMode: d["seedMode"]?.asInt32 ?? 2
        )
    }

    // MARK: - Nested parsing

    private static func parseLoras(_ value: JSONValue?) -> [LoRAConfig] {
        guard case .array(let items) = value else { return [] }
        return items.compactMap { item -> LoRAConfig? in
            guard case .object(let pairs) = item else { return nil }
            let d = Dictionary(pairs.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })
            guard let file = d["file"]?.asString, !file.isEmpty else { return nil }
            let weight = d["weight"]?.asFloat ?? 1.0
            let mode: LoRAMode
            if let s = d["mode"]?.asString {
                mode = mapLoRAModeString(s)
            } else if let i = d["mode"]?.asInt32, let i8 = Int8(exactly: i) {
                mode = LoRAMode(rawValue: i8) ?? .all
            } else {
                mode = .all
            }
            return LoRAConfig(file: file, weight: weight, mode: mode)
        }
    }

    private static func parseControls(_ value: JSONValue?) -> [ControlConfig] {
        guard case .array(let items) = value else { return [] }
        return items.compactMap { item -> ControlConfig? in
            guard case .object(let pairs) = item else { return nil }
            let d = Dictionary(pairs.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })
            guard let file = d["file"]?.asString, !file.isEmpty else { return nil }
            let weight = d["weight"]?.asFloat ?? 1.0
            let guidanceStart = d["guidanceStart"]?.asFloat ?? 0.0
            let guidanceEnd = d["guidanceEnd"]?.asFloat ?? 1.0
            let controlMode: ControlMode
            if let s = d["controlImportance"]?.asString {
                controlMode = mapControlModeString(s)
            } else if let i = d["controlImportance"]?.asInt32, let i8 = Int8(exactly: i) {
                controlMode = ControlMode(rawValue: i8) ?? .balanced
            } else {
                controlMode = .balanced
            }
            return ControlConfig(
                file: file, weight: weight,
                guidanceStart: guidanceStart, guidanceEnd: guidanceEnd,
                controlMode: controlMode)
        }
    }

    // MARK: - Config -> key-value pairs

    private static func configToKeyValues(_ c: DrawThingsConfiguration) -> [(String, JSONValue)] {
        let pairs: [(String, JSONValue)] = [
            ("model", .string(c.model)),
            ("width", intVal(c.width)),
            ("height", intVal(c.height)),
            ("steps", intVal(c.steps)),
            ("sampler", intVal(Int32(c.sampler.rawValue))),
            ("guidanceScale", floatVal(c.guidanceScale)),
            ("seed", c.seed.map { .int("\($0)") } ?? .null),
            ("clipSkip", intVal(c.clipSkip)),
            ("shift", floatVal(c.shift)),
            ("batchCount", intVal(c.batchCount)),
            ("batchSize", intVal(c.batchSize)),
            ("strength", floatVal(c.strength)),
            ("imageGuidanceScale", floatVal(c.imageGuidanceScale)),
            ("clipWeight", floatVal(c.clipWeight)),
            ("guidanceEmbed", floatVal(c.guidanceEmbed)),
            ("speedUpWithGuidanceEmbed", .bool(c.speedUpWithGuidanceEmbed)),
            ("cfgZeroStar", .bool(c.cfgZeroStar)),
            ("cfgZeroInitSteps", intVal(c.cfgZeroInitSteps)),
            ("compressionArtifacts", .string(compressionString(c.compressionArtifacts))),
            ("compressionArtifactsQuality", floatVal(c.compressionArtifactsQuality)),
            ("colorCalibration", .string(colorCalibrationString(c.colorCalibration))),
            ("maskBlur", floatVal(c.maskBlur)),
            ("maskBlurOutset", intVal(c.maskBlurOutset)),
            ("preserveOriginalAfterInpaint", .bool(c.preserveOriginalAfterInpaint)),
            ("enableInpainting", .bool(c.enableInpainting)),
            ("sharpness", floatVal(c.sharpness)),
            ("stochasticSamplingGamma", floatVal(c.stochasticSamplingGamma)),
            ("aestheticScore", floatVal(c.aestheticScore)),
            ("negativeAestheticScore", floatVal(c.negativeAestheticScore)),
            ("negativePromptForImagePrior", .bool(c.negativePromptForImagePrior)),
            ("imagePriorSteps", intVal(c.imagePriorSteps)),
            ("cropTop", intVal(c.cropTop)),
            ("cropLeft", intVal(c.cropLeft)),
            ("originalImageHeight", intVal(c.originalImageHeight)),
            ("originalImageWidth", intVal(c.originalImageWidth)),
            ("targetImageHeight", intVal(c.targetImageHeight)),
            ("targetImageWidth", intVal(c.targetImageWidth)),
            ("negativeOriginalImageHeight", intVal(c.negativeOriginalImageHeight)),
            ("negativeOriginalImageWidth", intVal(c.negativeOriginalImageWidth)),
            ("upscalerScaleFactor", intVal(c.upscalerScaleFactor)),
            ("resolutionDependentShift", .bool(c.resolutionDependentShift)),
            ("t5TextEncoder", .bool(c.t5TextEncoder)),
            ("separateClipL", .bool(c.separateClipL)),
            ("separateOpenClipG", .bool(c.separateOpenClipG)),
            ("separateT5", .bool(c.separateT5)),
            ("tiledDiffusion", .bool(c.tiledDiffusion)),
            ("diffusionTileWidth", intVal(c.diffusionTileWidth)),
            ("diffusionTileHeight", intVal(c.diffusionTileHeight)),
            ("diffusionTileOverlap", intVal(c.diffusionTileOverlap)),
            ("tiledDecoding", .bool(c.tiledDecoding)),
            ("decodingTileWidth", intVal(c.decodingTileWidth)),
            ("decodingTileHeight", intVal(c.decodingTileHeight)),
            ("decodingTileOverlap", intVal(c.decodingTileOverlap)),
            ("hiresFix", .bool(c.hiresFix)),
            ("hiresFixWidth", intVal(c.hiresFixWidth)),
            ("hiresFixHeight", intVal(c.hiresFixHeight)),
            ("hiresFixStrength", floatVal(c.hiresFixStrength)),
            ("stage2Steps", intVal(c.stage2Steps)),
            ("stage2Guidance", floatVal(c.stage2Guidance)),
            ("stage2Shift", floatVal(c.stage2Shift)),
            ("teaCache", .bool(c.teaCache)),
            ("teaCacheStart", intVal(c.teaCacheStart)),
            ("teaCacheEnd", intVal(c.teaCacheEnd)),
            ("teaCacheThreshold", floatVal(c.teaCacheThreshold)),
            ("teaCacheMaxSkipSteps", intVal(c.teaCacheMaxSkipSteps)),
            ("causalInferenceEnabled", .bool(c.causalInferenceEnabled)),
            ("causalInference", intVal(c.causalInference)),
            ("causalInferencePad", intVal(c.causalInferencePad)),
            ("fps", intVal(c.fps)),
            ("motionScale", intVal(c.motionScale)),
            ("guidingFrameNoise", floatVal(c.guidingFrameNoise)),
            ("startFrameGuidance", floatVal(c.startFrameGuidance)),
            ("numFrames", intVal(c.numFrames)),
            ("refinerModel", c.refinerModel.map { .string($0) } ?? .null),
            ("refinerStart", floatVal(c.refinerStart)),
            ("zeroNegativePrompt", .bool(c.zeroNegativePrompt)),
            ("upscaler", c.upscaler.map { .string($0) } ?? .null),
            ("faceRestoration", c.faceRestoration.map { .string($0) } ?? .null),
            ("clipLText", c.clipLText.map { .string($0) } ?? .null),
            ("openClipGText", c.openClipGText.map { .string($0) } ?? .null),
            ("t5Text", c.t5Text.map { .string($0) } ?? .null),
            ("seedMode", intVal(c.seedMode)),
            ("name", c.name.map { .string($0) } ?? .null),
            ("loras", lorasToJSON(c.loras)),
            ("controls", controlsToJSON(c.controls)),
        ]
        return pairs
    }

    private static func lorasToJSON(_ loras: [LoRAConfig]) -> JSONValue {
        .array(loras.map { lora in
            .object([
                (key: "file", value: .string(lora.file)),
                (key: "mode", value: .string(loraModeString(lora.mode))),
                (key: "weight", value: floatVal(lora.weight)),
            ])
        })
    }

    private static func controlsToJSON(_ controls: [ControlConfig]) -> JSONValue {
        .array(controls.map { c in
            .object([
                (key: "controlImportance", value: .string(controlModeString(c.controlMode))),
                (key: "file", value: .string(c.file)),
                (key: "guidanceEnd", value: floatVal(c.guidanceEnd)),
                (key: "guidanceStart", value: floatVal(c.guidanceStart)),
                (key: "weight", value: floatVal(c.weight)),
            ])
        })
    }

    // MARK: - JSON emission

    private static func emitJSON(_ pairs: [(String, JSONValue)]) -> String {
        if pairs.isEmpty { return "{}" }
        var lines: [String] = ["{"]
        for (i, (key, value)) in pairs.enumerated() {
            let comma = i < pairs.count - 1 ? "," : ""
            let valueStr = serializeValue(value, indent: 1)
            lines.append("  \"\(escapeJSON(key))\": \(valueStr)\(comma)")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    static func serializeValue(_ value: JSONValue, indent: Int = 0) -> String {
        switch value {
        case .null: return "null"
        case .bool(true): return "true"
        case .bool(false): return "false"
        case .int(let s): return s
        case .float(let s): return s
        case .string(let s): return "\"\(escapeJSON(s))\""
        case .array(let elements):
            if elements.isEmpty { return "[]" }
            let inner = String(repeating: "  ", count: indent + 1)
            let outer = String(repeating: "  ", count: indent)
            let items = elements.map { "\(inner)\(serializeValue($0, indent: indent + 1))" }
            return "[\n\(items.joined(separator: ",\n"))\n\(outer)]"
        case .object(let pairs):
            if pairs.isEmpty { return "{}" }
            let inner = String(repeating: "  ", count: indent + 1)
            let outer = String(repeating: "  ", count: indent)
            let items = pairs.map { "\(inner)\"\(escapeJSON($0.key))\": \(serializeValue($0.value, indent: indent + 1))" }
            return "{\n\(items.joined(separator: ",\n"))\n\(outer)}"
        }
    }

    private static func escapeJSON(_ s: String) -> String {
        var out = ""
        for ch in s {
            switch ch {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default: out.append(ch)
            }
        }
        return out
    }

    // MARK: - Value helpers

    private static func intVal(_ v: Int32) -> JSONValue { .int("\(v)") }

    private static func floatVal(_ v: Float) -> JSONValue {
        if v.truncatingRemainder(dividingBy: 1) == 0 &&
            !v.isNaN && !v.isInfinite &&
            abs(v) <= Float(Int32.max)
        {
            return .int("\(Int32(v))")
        }
        return .float(String(v))
    }

    private static func numericEqual(_ a: JSONValue, _ b: JSONValue) -> Bool {
        switch (a, b) {
        case (.null, .null): return true
        case (.bool(let x), .bool(let y)): return x == y
        case (.string(let x), .string(let y)): return x == y
        case (.int(let x), .int(let y)): return Int(x) == Int(y)
        case (.float(let x), .float(let y)): return Double(x) == Double(y)
        case (.int(let x), .float(let y)): return Double(x) == Double(y)
        case (.float(let x), .int(let y)): return Double(x) == Double(y)
        case (.array(let x), .array(let y)):
            guard x.count == y.count else { return false }
            return zip(x, y).allSatisfy { numericEqual($0, $1) }
        case (.object(let x), .object(let y)):
            guard x.count == y.count else { return false }
            return zip(x, y).allSatisfy { $0.key == $1.key && numericEqual($0.value, $1.value) }
        default:
            return false
        }
    }

    // MARK: - String/enum mapping

    private static func coalesceEmpty(_ v: JSONValue?) -> String? {
        switch v {
        case .string(let s): return s.isEmpty ? nil : s
        case .null, .none: return nil
        default: return nil
        }
    }

    private static func mapCompressionString(_ s: String) -> CompressionMethod {
        switch s.lowercased() {
        case "disabled": return .disabled
        case "h264": return .h264
        case "h265": return .h265
        case "jpeg": return .jpeg
        default: return .disabled
        }
    }

    private static func compressionString(_ m: CompressionMethod) -> String {
        switch m {
        case .disabled: return "disabled"
        case .h264: return "h264"
        case .h265: return "h265"
        case .jpeg: return "jpeg"
        }
    }

    private static func mapLoRAModeString(_ s: String) -> LoRAMode {
        switch s.lowercased() {
        case "all": return .all
        case "base": return .base
        case "refiner": return .refiner
        default: return .all
        }
    }

    private static func loraModeString(_ m: LoRAMode) -> String {
        switch m {
        case .all: return "all"
        case .base: return "base"
        case .refiner: return "refiner"
        }
    }

    private static func mapControlModeString(_ s: String) -> ControlMode {
        switch s.lowercased() {
        case "balanced": return .balanced
        case "prompt": return .prompt
        case "control": return .control
        default: return .balanced
        }
    }

    private static func controlModeString(_ m: ControlMode) -> String {
        switch m {
        case .balanced: return "balanced"
        case .prompt: return "prompt"
        case .control: return "control"
        }
    }

    private static func mapColorCalibrationString(_ s: String) -> ColorCalibration {
        switch s.lowercased() {
        case "none", "disabled": return .disabled
        case "lab": return .lab
        default: return .disabled
        }
    }

    private static func colorCalibrationString(_ c: ColorCalibration) -> String {
        switch c {
        case .disabled: return "none"
        case .lab: return "lab"
        }
    }
}

// MARK: - JSONValue convenience

extension JSONValue {
    var asString: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var asBool: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    var asInt32: Int32? {
        switch self {
        case .int(let s): return Int32(s)
        case .float(let s): return Int32(Double(s) ?? 0)
        default: return nil
        }
    }

    var asInt64: Int64? {
        if case .int(let s) = self { return Int64(s) }
        return nil
    }

    var asFloat: Float? {
        switch self {
        case .float(let s): return Float(Double(s) ?? 0)
        case .int(let s): return Float(Int(s) ?? 0)
        default: return nil
        }
    }

    var asOptionalString: String? {
        switch self {
        case .null: return nil
        case .string(let s): return s
        default: return nil
        }
    }
}
