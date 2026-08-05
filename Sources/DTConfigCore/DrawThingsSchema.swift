public enum DrawThingsSchema {

    // MARK: - Sampler labels

    public static let samplerLabels: [Int: String] = [
        0: "dpmpp2mkarras", 1: "eulera", 2: "ddim", 3: "plms",
        4: "dpmppsdekarras", 5: "unipc", 6: "lcm", 7: "eulerasubstep",
        8: "dpmppsdesubstep", 9: "tcd", 10: "euleratrailing",
        11: "dpmppsdetrailing", 12: "dpmpp2mays", 13: "euleraays",
        14: "dpmppsdeays", 15: "dpmpp2mtrailing", 16: "ddimtrailing",
        17: "unipctrailing", 18: "unipcays", 19: "tcdtrailing",
    ]

    public static let seedModeLabels: [Int: String] = [
        0: "legacy", 1: "torchcpucompatible", 2: "scalealike", 3: "nvidiagpucompatible",
    ]

    // MARK: - Nested schemas

    public static let loraSchema = ObjectSchema(fields: [
        "file": FieldSchema(
            type: .string, label: "File", domainPath: .loraFile),
        "weight": FieldSchema(
            type: .float, jsonDefault: .float("1.0"), label: "Weight"),
        "mode": FieldSchema(
            type: .stringOrIntEnum(
                name: "LoRAMode",
                strings: ["all", "base", "refiner"],
                intRange: 0...2),
            jsonDefault: .int("0"),
            label: "Mode"),
    ])

    public static let controlSchema = ObjectSchema(fields: [
        // Core fields parsed by ConfigfromJSON
        "file": FieldSchema(
            type: .string, label: "File", domainPath: .controlFile),
        "weight": FieldSchema(
            type: .float, jsonDefault: .float("1.0"), label: "Weight"),
        "guidanceStart": FieldSchema(
            type: .float, jsonDefault: .float("0.0"), label: "Guidance Start"),
        "guidanceEnd": FieldSchema(
            type: .float, jsonDefault: .float("1.0"), label: "Guidance End"),
        "controlImportance": FieldSchema(
            type: .stringOrIntEnum(
                name: "ControlMode",
                strings: ["balanced", "prompt", "control"],
                intRange: 0...2),
            jsonDefault: .int("0"),
            label: "Control Importance"),
        // Extra FlatBuffer fields exported by Draw Things but not parsed by ConfigfromJSON
        "noPrompt": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),
        "globalAveragePooling": FieldSchema(
            type: .bool, jsonDefault: .bool(true)),
        "downSamplingRate": FieldSchema(
            type: .float, jsonDefault: .float("1.0")),
        "targetBlocks": FieldSchema(
            type: .stringArray, jsonDefault: .array([])),
        "inputOverride": FieldSchema(
            type: .string, jsonDefault: .string("")),
    ])

    // MARK: - Root schema

    public static let root = ObjectSchema(fields: [
        // --- Metadata ---
        "name": FieldSchema(
            type: .nullableString, jsonDefault: .null, label: "Configuration Name"),

        // --- Core ---
        "model": FieldSchema(
            type: .string, label: "Model", domainPath: .model),
        "width": FieldSchema(
            type: .int, jsonDefault: .int("1024"), multipleOf64: true, label: "Width"),
        "height": FieldSchema(
            type: .int, jsonDefault: .int("1024"), multipleOf64: true, label: "Height"),
        "steps": FieldSchema(
            type: .int, jsonDefault: .int("20"), label: "Steps"),
        "sampler": FieldSchema(
            type: .intEnum(name: "SamplerType", range: 0...19, labels: samplerLabels),
            jsonDefault: .int("0"),
            label: "Sampler"),
        "guidanceScale": FieldSchema(
            type: .float, jsonDefault: .float("7.0"), label: "Guidance Scale"),
        "seed": FieldSchema(
            type: .nullableInt, jsonDefault: .null, label: "Seed",
            doc: "-1 or null means random"),
        "clipSkip": FieldSchema(
            type: .int, jsonDefault: .int("1"), label: "CLIP Skip"),
        "shift": FieldSchema(
            type: .float, jsonDefault: .float("1.0"), label: "Shift"),
        "strength": FieldSchema(
            type: .float, jsonDefault: .float("1.0"), label: "Strength"),

        // --- Batch ---
        "batchCount": FieldSchema(
            type: .int, jsonDefault: .int("1"), label: "Batch Count"),
        "batchSize": FieldSchema(
            type: .int, jsonDefault: .int("1"), label: "Batch Size"),

        // --- Guidance ---
        "imageGuidanceScale": FieldSchema(
            type: .float, jsonDefault: .float("1.5"), label: "Image Guidance Scale"),
        "clipWeight": FieldSchema(
            type: .float, jsonDefault: .float("1.0"), label: "CLIP Weight"),
        "guidanceEmbed": FieldSchema(
            type: .float, jsonDefault: .float("3.5"), label: "Guidance Embed"),
        "speedUpWithGuidanceEmbed": FieldSchema(
            type: .bool, jsonDefault: .bool(true)),
        "cfgZeroStar": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),
        "cfgZeroInitSteps": FieldSchema(
            type: .int, jsonDefault: .int("0")),

        // --- Compression ---
        "compressionArtifacts": FieldSchema(
            type: .stringOrIntEnum(
                name: "CompressionMethod",
                strings: ["disabled", "h264", "h265", "jpeg"],
                intRange: 0...3),
            jsonDefault: .int("0"),
            label: "Compression Artifacts"),
        "compressionArtifactsQuality": FieldSchema(
            type: .float, jsonDefault: .float("43.1")),

        // --- Mask / Inpaint ---
        "maskBlur": FieldSchema(
            type: .float, jsonDefault: .float("1.5")),
        "maskBlurOutset": FieldSchema(
            type: .int, jsonDefault: .int("0")),
        "preserveOriginalAfterInpaint": FieldSchema(
            type: .bool, jsonDefault: .bool(true)),
        "enableInpainting": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),

        // --- Quality ---
        "sharpness": FieldSchema(
            type: .float, jsonDefault: .float("0.0")),
        "stochasticSamplingGamma": FieldSchema(
            type: .float, jsonDefault: .float("0.3")),
        "aestheticScore": FieldSchema(
            type: .float, jsonDefault: .float("6.0")),
        "negativeAestheticScore": FieldSchema(
            type: .float, jsonDefault: .float("2.5")),

        // --- Image Prior ---
        "negativePromptForImagePrior": FieldSchema(
            type: .bool, jsonDefault: .bool(true)),
        "imagePriorSteps": FieldSchema(
            type: .int, jsonDefault: .int("5")),

        // --- Crop / Size ---
        "cropTop": FieldSchema(
            type: .int, jsonDefault: .int("0")),
        "cropLeft": FieldSchema(
            type: .int, jsonDefault: .int("0")),
        "originalImageHeight": FieldSchema(
            type: .int, jsonDefault: .int("0"), multipleOf64: true),
        "originalImageWidth": FieldSchema(
            type: .int, jsonDefault: .int("0"), multipleOf64: true),
        "targetImageHeight": FieldSchema(
            type: .int, jsonDefault: .int("0"), multipleOf64: true),
        "targetImageWidth": FieldSchema(
            type: .int, jsonDefault: .int("0"), multipleOf64: true),
        "negativeOriginalImageHeight": FieldSchema(
            type: .int, jsonDefault: .int("0"), multipleOf64: true),
        "negativeOriginalImageWidth": FieldSchema(
            type: .int, jsonDefault: .int("0"), multipleOf64: true),

        // --- Upscaler ---
        "upscaler": FieldSchema(
            type: .nullableString, jsonDefault: .null, label: "Upscaler",
            domainPath: .upscaler),
        "upscalerScaleFactor": FieldSchema(
            type: .int, jsonDefault: .int("0")),

        // --- Text Encoder ---
        "resolutionDependentShift": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),
        "t5TextEncoder": FieldSchema(
            type: .bool, jsonDefault: .bool(true)),
        "separateClipL": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),
        "separateOpenClipG": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),
        "separateT5": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),

        // --- Separate Text Encoder Prompts ---
        "clipLText": FieldSchema(
            type: .nullableString, jsonDefault: .null),
        "openClipGText": FieldSchema(
            type: .nullableString, jsonDefault: .null),
        "t5Text": FieldSchema(
            type: .nullableString, jsonDefault: .null),

        // --- Tiled Diffusion ---
        "tiledDiffusion": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),
        "diffusionTileWidth": FieldSchema(
            type: .int, jsonDefault: .int("1024"), multipleOf64: true),
        "diffusionTileHeight": FieldSchema(
            type: .int, jsonDefault: .int("1024"), multipleOf64: true),
        "diffusionTileOverlap": FieldSchema(
            type: .int, jsonDefault: .int("128"), multipleOf64: true),

        // --- Tiled Decoding ---
        "tiledDecoding": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),
        "decodingTileWidth": FieldSchema(
            type: .int, jsonDefault: .int("640"), multipleOf64: true),
        "decodingTileHeight": FieldSchema(
            type: .int, jsonDefault: .int("640"), multipleOf64: true),
        "decodingTileOverlap": FieldSchema(
            type: .int, jsonDefault: .int("128")),

        // --- HiRes Fix ---
        "hiresFix": FieldSchema(
            type: .bool, jsonDefault: .bool(false), label: "HiRes Fix"),
        "hiresFixWidth": FieldSchema(
            type: .int, jsonDefault: .int("1024"), multipleOf64: true,
            doc: "0 is a valid sentinel meaning 'use main width'"),
        "hiresFixHeight": FieldSchema(
            type: .int, jsonDefault: .int("1024"), multipleOf64: true,
            doc: "0 is a valid sentinel meaning 'use main height'"),
        "hiresFixStrength": FieldSchema(
            type: .float, jsonDefault: .float("0.7")),

        // --- Stage 2 ---
        "stage2Steps": FieldSchema(
            type: .int, jsonDefault: .int("10")),
        "stage2Guidance": FieldSchema(
            type: .float, jsonDefault: .float("1.0")),
        "stage2Shift": FieldSchema(
            type: .float, jsonDefault: .float("1.0")),

        // --- TEA Cache ---
        "teaCache": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),
        "teaCacheStart": FieldSchema(
            type: .int, jsonDefault: .int("5")),
        "teaCacheEnd": FieldSchema(
            type: .int, jsonDefault: .int("-1"),
            doc: "-1 is a valid sentinel"),
        "teaCacheThreshold": FieldSchema(
            type: .float, jsonDefault: .float("0.2")),
        "teaCacheMaxSkipSteps": FieldSchema(
            type: .int, jsonDefault: .int("3")),

        // --- Causal Inference ---
        "causalInferenceEnabled": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),
        "causalInference": FieldSchema(
            type: .int, jsonDefault: .int("0")),
        "causalInferencePad": FieldSchema(
            type: .int, jsonDefault: .int("0")),

        // --- Video ---
        "fps": FieldSchema(
            type: .int, jsonDefault: .int("5"),
            doc: "Inert on image models"),
        "motionScale": FieldSchema(
            type: .int, jsonDefault: .int("127"),
            doc: "Inert on image models"),
        "guidingFrameNoise": FieldSchema(
            type: .float, jsonDefault: .float("0.02"),
            doc: "Inert on image models"),
        "startFrameGuidance": FieldSchema(
            type: .float, jsonDefault: .float("1.0"),
            doc: "Inert on image models"),
        "numFrames": FieldSchema(
            type: .int, jsonDefault: .int("14"),
            doc: "Inert on image models"),

        // --- Refiner ---
        "refinerModel": FieldSchema(
            type: .nullableString, jsonDefault: .null, label: "Refiner Model"),
        "refinerStart": FieldSchema(
            type: .float, jsonDefault: .float("0.85")),
        "zeroNegativePrompt": FieldSchema(
            type: .bool, jsonDefault: .bool(false)),

        // --- Face Restoration ---
        "faceRestoration": FieldSchema(
            type: .nullableString, jsonDefault: .null),

        // --- Seed Mode ---
        "seedMode": FieldSchema(
            type: .intEnum(name: "SeedMode", range: 0...3, labels: seedModeLabels),
            jsonDefault: .int("2")),

        // --- Arrays ---
        "loras": FieldSchema(
            type: .array(FieldSchema(type: .object(loraSchema))),
            jsonDefault: .array([]),
            label: "LoRAs"),
        "controls": FieldSchema(
            type: .array(FieldSchema(type: .object(controlSchema))),
            jsonDefault: .array([]),
            label: "Controls"),

        // --- Color Calibration (exported by DT, not parsed by ConfigfromJSON) ---
        "colorCalibration": FieldSchema(
            type: .stringOrIntEnum(
                name: "ColorCalibration",
                strings: ["none", "disabled", "lab"],
                intRange: 0...1),
            jsonDefault: .int("0")),
    ])
}
