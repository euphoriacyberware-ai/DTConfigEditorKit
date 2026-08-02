import Foundation

// MARK: - Known keys

extension DrawThingsConfiguration {

    /// Every JSON key that maps to a typed property on this struct.
    /// Used to partition parsed dictionaries into typed fields vs. overflow.
    static let knownKeys: Set<String> = [
        "aestheticScore", "batchCount", "batchSize",
        "causalInference", "causalInferencePad",
        "cfgZeroInitSteps", "cfgZeroStar",
        "clipLText", "clipSkip", "clipWeight",
        "compressionArtifacts", "compressionArtifactsQuality",
        "controls", "cropLeft", "cropTop",
        "decodingTileHeight", "decodingTileOverlap", "decodingTileWidth",
        "diffusionTileHeight", "diffusionTileOverlap", "diffusionTileWidth",
        "faceRestoration", "fps",
        "guidanceEmbed", "guidanceScale", "guidingFrameNoise",
        "height", "hiresFix", "hiresFixHeight", "hiresFixStrength", "hiresFixWidth",
        "id", "imageGuidanceScale", "imagePriorSteps",
        "loras",
        "maskBlur", "maskBlurOutset", "model", "motionScale",
        "negativeAestheticScore", "negativeOriginalImageHeight", "negativeOriginalImageWidth",
        "negativePromptForImagePrior", "numFrames",
        "openClipGText", "originalImageHeight", "originalImageWidth",
        "preserveOriginalAfterInpaint",
        "refinerModel", "refinerStart", "resolutionDependentShift",
        "sampler", "seed", "seedMode",
        "separateClipL", "separateOpenClipG", "separateT5",
        "sharpness", "shift", "speedUpWithGuidanceEmbed",
        "stage2Guidance", "stage2Shift", "stage2Steps", "startFrameGuidance",
        "steps", "stochasticSamplingGamma", "strength",
        "t5TextEncoder", "targetImageHeight", "targetImageWidth",
        "teaCache", "teaCacheEnd", "teaCacheMaxSkipSteps", "teaCacheStart", "teaCacheThreshold",
        "tiledDecoding", "tiledDiffusion",
        "upscaler", "upscalerScaleFactor",
        "width", "zeroNegativePrompt",
    ]
}

// MARK: - Parsing from JSON data

extension DrawThingsConfiguration {

    public enum ParseError: Error {
        case notAJSONObject
    }

    /// Decode a Draw Things configuration from raw JSON data.
    ///
    /// Uses `JSONSerialization` internally so that boolean vs. integer
    /// types are correctly distinguished (via `CFBooleanGetTypeID`).
    public init(jsonData data: Data) throws {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.notAJSONObject
        }
        try self.init(foundationDict: dict)
    }

    init(foundationDict dict: [String: Any]) throws {
        // MARK: Generation parameters
        model = dict.string("model") ?? ""
        sampler = dict.int("sampler")
        steps = dict.int("steps", or: 20)
        guidanceScale = dict.double("guidanceScale", or: 7.0)
        seed = dict.int("seed")
        seedMode = dict.int("seedMode")
        strength = dict.double("strength", or: 1.0)
        batchCount = dict.int("batchCount", or: 1)
        batchSize = dict.int("batchSize", or: 1)
        width = dict.int("width", or: 512)
        height = dict.int("height", or: 512)

        // MARK: Aesthetic / quality
        aestheticScore = dict.double("aestheticScore", or: 6.0)
        negativeAestheticScore = dict.double("negativeAestheticScore", or: 2.5)
        sharpness = dict.double("sharpness")
        clipSkip = dict.int("clipSkip", or: 1)
        clipWeight = dict.double("clipWeight", or: 1.0)

        // MARK: Guidance & embeddings
        guidanceEmbed = dict.double("guidanceEmbed", or: 3.5)
        speedUpWithGuidanceEmbed = dict.bool("speedUpWithGuidanceEmbed")
        imageGuidanceScale = dict.double("imageGuidanceScale", or: 1.5)
        imagePriorSteps = dict.int("imagePriorSteps", or: 5)
        negativePromptForImagePrior = dict.bool("negativePromptForImagePrior")
        stochasticSamplingGamma = dict.double("stochasticSamplingGamma", or: 0.3)

        // MARK: CFG-Zero
        cfgZeroStar = dict.bool("cfgZeroStar")
        cfgZeroInitSteps = dict.int("cfgZeroInitSteps")

        // MARK: Text encoder controls
        separateClipL = dict.bool("separateClipL")
        clipLText = dict.string("clipLText")
        separateOpenClipG = dict.bool("separateOpenClipG")
        openClipGText = dict.string("openClipGText")
        separateT5 = dict.bool("separateT5")
        t5TextEncoder = dict.bool("t5TextEncoder")
        zeroNegativePrompt = dict.bool("zeroNegativePrompt")

        // MARK: Hires fix
        hiresFix = dict.bool("hiresFix")
        hiresFixWidth = dict.int("hiresFixWidth")
        hiresFixHeight = dict.int("hiresFixHeight")
        hiresFixStrength = dict.double("hiresFixStrength", or: 0.7)

        // MARK: Tiled decoding / diffusion
        tiledDecoding = dict.bool("tiledDecoding")
        decodingTileWidth = dict.int("decodingTileWidth", or: 640)
        decodingTileHeight = dict.int("decodingTileHeight", or: 640)
        decodingTileOverlap = dict.int("decodingTileOverlap", or: 128)
        tiledDiffusion = dict.bool("tiledDiffusion")
        diffusionTileWidth = dict.int("diffusionTileWidth", or: 1024)
        diffusionTileHeight = dict.int("diffusionTileHeight", or: 1024)
        diffusionTileOverlap = dict.int("diffusionTileOverlap", or: 128)

        // MARK: Upscaler
        upscaler = dict.string("upscaler")
        upscalerScaleFactor = dict.int("upscalerScaleFactor")

        // MARK: Face restoration
        faceRestoration = dict.string("faceRestoration")

        // MARK: Refiner
        refinerModel = dict.string("refinerModel")
        refinerStart = dict.double("refinerStart", or: 0.85)

        // MARK: Inpainting
        maskBlur = dict.double("maskBlur", or: 1.5)
        maskBlurOutset = dict.double("maskBlurOutset")
        preserveOriginalAfterInpaint = dict.bool("preserveOriginalAfterInpaint")

        // MARK: Crop / original image size
        cropLeft = dict.int("cropLeft")
        cropTop = dict.int("cropTop")
        originalImageWidth = dict.int("originalImageWidth")
        originalImageHeight = dict.int("originalImageHeight")
        negativeOriginalImageWidth = dict.int("negativeOriginalImageWidth")
        negativeOriginalImageHeight = dict.int("negativeOriginalImageHeight")
        targetImageWidth = dict.int("targetImageWidth")
        targetImageHeight = dict.int("targetImageHeight")

        // MARK: Compression artifacts
        compressionArtifacts = dict.string("compressionArtifacts") ?? "disabled"
        compressionArtifactsQuality = dict.double("compressionArtifactsQuality")

        // MARK: Shift
        shift = dict.double("shift", or: 3.0)
        resolutionDependentShift = dict.bool("resolutionDependentShift")

        // MARK: Stage 2
        stage2Guidance = dict.double("stage2Guidance", or: 1.0)
        stage2Shift = dict.double("stage2Shift", or: 1.0)
        stage2Steps = dict.int("stage2Steps", or: 10)
        startFrameGuidance = dict.double("startFrameGuidance", or: 1.0)

        // MARK: Video / animation
        fps = dict.int("fps", or: 5)
        numFrames = dict.int("numFrames", or: 14)
        motionScale = dict.int("motionScale", or: 127)
        guidingFrameNoise = dict.double("guidingFrameNoise", or: 0.02)

        // MARK: TeaCache
        teaCache = dict.bool("teaCache")
        teaCacheStart = dict.double("teaCacheStart", or: 5.0)
        teaCacheEnd = dict.double("teaCacheEnd", or: -1.0)
        teaCacheThreshold = dict.double("teaCacheThreshold", or: 0.2)
        teaCacheMaxSkipSteps = dict.int("teaCacheMaxSkipSteps", or: 3)

        // MARK: Causal inference
        causalInference = dict.double("causalInference")
        causalInferencePad = dict.int("causalInferencePad")

        // MARK: Misc
        id = dict.int("id")

        // MARK: LoRAs
        if let lorasArray = dict["loras"] as? [[String: Any]] {
            loras = try lorasArray.map { try LoRAConfiguration(foundationDict: $0) }
        } else {
            loras = []
        }

        // MARK: Controls (kept as JSONValue until roadmap step 6)
        if let controlsArray = dict["controls"] as? [Any] {
            controls = try controlsArray.map { try JSONValue.convert($0) }
        } else {
            controls = []
        }

        // MARK: Overflow — everything not in knownKeys
        var overflow: [String: JSONValue] = [:]
        for key in dict.keys where !Self.knownKeys.contains(key) {
            overflow[key] = try JSONValue.convert(dict[key]!)
        }
        self.overflow = overflow
    }
}

// MARK: - Serialization to JSON data

extension DrawThingsConfiguration {

    /// Re-encode this configuration to JSON data.
    ///
    /// Known fields are written first, then overflow keys are merged in.
    /// Key order in the output may differ from the original — this is
    /// expected (architecture rule 3).
    public func jsonData(options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]) throws -> Data {
        var dict: [String: Any] = [:]

        // Generation parameters
        dict["model"] = model
        dict["sampler"] = sampler
        dict["steps"] = steps
        dict["guidanceScale"] = guidanceScale
        dict["seed"] = seed
        dict["seedMode"] = seedMode
        dict["strength"] = strength
        dict["batchCount"] = batchCount
        dict["batchSize"] = batchSize
        dict["width"] = width
        dict["height"] = height

        // Aesthetic / quality
        dict["aestheticScore"] = aestheticScore
        dict["negativeAestheticScore"] = negativeAestheticScore
        dict["sharpness"] = sharpness
        dict["clipSkip"] = clipSkip
        dict["clipWeight"] = clipWeight

        // Guidance & embeddings
        dict["guidanceEmbed"] = guidanceEmbed
        dict["speedUpWithGuidanceEmbed"] = speedUpWithGuidanceEmbed
        dict["imageGuidanceScale"] = imageGuidanceScale
        dict["imagePriorSteps"] = imagePriorSteps
        dict["negativePromptForImagePrior"] = negativePromptForImagePrior
        dict["stochasticSamplingGamma"] = stochasticSamplingGamma

        // CFG-Zero
        dict["cfgZeroStar"] = cfgZeroStar
        dict["cfgZeroInitSteps"] = cfgZeroInitSteps

        // Text encoder controls
        dict["separateClipL"] = separateClipL
        setNullable(&dict, "clipLText", clipLText)
        dict["separateOpenClipG"] = separateOpenClipG
        setNullable(&dict, "openClipGText", openClipGText)
        dict["separateT5"] = separateT5
        dict["t5TextEncoder"] = t5TextEncoder
        dict["zeroNegativePrompt"] = zeroNegativePrompt

        // Hires fix
        dict["hiresFix"] = hiresFix
        dict["hiresFixWidth"] = hiresFixWidth
        dict["hiresFixHeight"] = hiresFixHeight
        dict["hiresFixStrength"] = hiresFixStrength

        // Tiled decoding / diffusion
        dict["tiledDecoding"] = tiledDecoding
        dict["decodingTileWidth"] = decodingTileWidth
        dict["decodingTileHeight"] = decodingTileHeight
        dict["decodingTileOverlap"] = decodingTileOverlap
        dict["tiledDiffusion"] = tiledDiffusion
        dict["diffusionTileWidth"] = diffusionTileWidth
        dict["diffusionTileHeight"] = diffusionTileHeight
        dict["diffusionTileOverlap"] = diffusionTileOverlap

        // Upscaler
        setNullable(&dict, "upscaler", upscaler)
        dict["upscalerScaleFactor"] = upscalerScaleFactor

        // Face restoration
        setNullable(&dict, "faceRestoration", faceRestoration)

        // Refiner
        setNullable(&dict, "refinerModel", refinerModel)
        dict["refinerStart"] = refinerStart

        // Inpainting
        dict["maskBlur"] = maskBlur
        dict["maskBlurOutset"] = maskBlurOutset
        dict["preserveOriginalAfterInpaint"] = preserveOriginalAfterInpaint

        // Crop / original image size
        dict["cropLeft"] = cropLeft
        dict["cropTop"] = cropTop
        dict["originalImageWidth"] = originalImageWidth
        dict["originalImageHeight"] = originalImageHeight
        dict["negativeOriginalImageWidth"] = negativeOriginalImageWidth
        dict["negativeOriginalImageHeight"] = negativeOriginalImageHeight
        dict["targetImageWidth"] = targetImageWidth
        dict["targetImageHeight"] = targetImageHeight

        // Compression artifacts
        dict["compressionArtifacts"] = compressionArtifacts
        dict["compressionArtifactsQuality"] = compressionArtifactsQuality

        // Shift
        dict["shift"] = shift
        dict["resolutionDependentShift"] = resolutionDependentShift

        // Stage 2
        dict["stage2Guidance"] = stage2Guidance
        dict["stage2Shift"] = stage2Shift
        dict["stage2Steps"] = stage2Steps
        dict["startFrameGuidance"] = startFrameGuidance

        // Video / animation
        dict["fps"] = fps
        dict["numFrames"] = numFrames
        dict["motionScale"] = motionScale
        dict["guidingFrameNoise"] = guidingFrameNoise

        // TeaCache
        dict["teaCache"] = teaCache
        dict["teaCacheStart"] = teaCacheStart
        dict["teaCacheEnd"] = teaCacheEnd
        dict["teaCacheThreshold"] = teaCacheThreshold
        dict["teaCacheMaxSkipSteps"] = teaCacheMaxSkipSteps

        // Causal inference
        dict["causalInference"] = causalInference
        dict["causalInferencePad"] = causalInferencePad

        // Misc
        dict["id"] = id

        // LoRAs
        dict["loras"] = loras.map { $0.toFoundationDict() }

        // Controls
        dict["controls"] = controls.map { $0.toFoundation() }

        // Overflow — merge in unknown keys
        for (key, value) in overflow {
            dict[key] = value.toFoundation()
        }

        return try JSONSerialization.data(withJSONObject: dict, options: options)
    }
}

// MARK: - LoRA parsing

extension LoRAConfiguration {

    static let knownKeys: Set<String> = ["file", "weight", "mode"]

    init(foundationDict dict: [String: Any]) throws {
        file = dict.string("file") ?? ""
        weight = dict.double("weight", or: 1.0)
        mode = dict.string("mode") ?? "all"

        var overflow: [String: JSONValue] = [:]
        for key in dict.keys where !Self.knownKeys.contains(key) {
            overflow[key] = try JSONValue.convert(dict[key]!)
        }
        self.overflow = overflow
    }

    func toFoundationDict() -> [String: Any] {
        var dict: [String: Any] = [
            "file": file,
            "weight": weight,
            "mode": mode,
        ]
        for (key, value) in overflow {
            dict[key] = value.toFoundation()
        }
        return dict
    }
}

// MARK: - Dictionary extraction helpers

private extension Dictionary where Key == String, Value == Any {
    func int(_ key: String, or fallback: Int = 0) -> Int {
        (self[key] as? NSNumber)?.intValue ?? fallback
    }

    func double(_ key: String, or fallback: Double = 0) -> Double {
        (self[key] as? NSNumber)?.doubleValue ?? fallback
    }

    func bool(_ key: String, or fallback: Bool = false) -> Bool {
        if let number = self[key] as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue
        }
        return fallback
    }

    func string(_ key: String) -> String? {
        self[key] as? String
    }
}

// MARK: - Nullable field encoding helper

private func setNullable(_ dict: inout [String: Any], _ key: String, _ value: String?) {
    if let value {
        dict[key] = value
    } else {
        dict[key] = NSNull()
    }
}
