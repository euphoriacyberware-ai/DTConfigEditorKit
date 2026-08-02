/// A fully-typed representation of a Draw Things generation-configuration JSON.
///
/// All fields present in the known schema are typed properties. Any keys not
/// recognized by this model are preserved in `overflow` so they survive a
/// decode-edit-encode round trip (architecture rule 4).
///
/// The five nullable string fields (`clipLText`, `openClipGText`,
/// `faceRestoration`, `refinerModel`, `upscaler`) use `String?` where `nil`
/// means the JSON value was `null` (or absent). Empty-string normalization
/// is handled separately (roadmap step 3).
public struct DrawThingsConfiguration: Sendable, Equatable {

    // MARK: - Generation parameters

    public var model: String
    public var sampler: Int
    public var steps: Int
    public var guidanceScale: Double
    public var seed: Int
    public var seedMode: Int
    public var strength: Double
    public var batchCount: Int
    public var batchSize: Int
    public var width: Int
    public var height: Int

    // MARK: - Aesthetic / quality

    public var aestheticScore: Double
    public var negativeAestheticScore: Double
    public var sharpness: Double
    public var clipSkip: Int
    public var clipWeight: Double

    // MARK: - Guidance & embeddings

    public var guidanceEmbed: Double
    public var speedUpWithGuidanceEmbed: Bool
    public var imageGuidanceScale: Double
    public var imagePriorSteps: Int
    public var negativePromptForImagePrior: Bool
    public var stochasticSamplingGamma: Double

    // MARK: - CFG-Zero / CFG-Zero*

    public var cfgZeroStar: Bool
    public var cfgZeroInitSteps: Int

    // MARK: - Text encoder controls

    public var separateClipL: Bool
    public var clipLText: String?
    public var separateOpenClipG: Bool
    public var openClipGText: String?
    public var separateT5: Bool
    public var t5TextEncoder: Bool
    public var zeroNegativePrompt: Bool

    // MARK: - Hires fix

    public var hiresFix: Bool
    public var hiresFixWidth: Int
    public var hiresFixHeight: Int
    public var hiresFixStrength: Double

    // MARK: - Tiled decoding / diffusion

    public var tiledDecoding: Bool
    public var decodingTileWidth: Int
    public var decodingTileHeight: Int
    public var decodingTileOverlap: Int
    public var tiledDiffusion: Bool
    public var diffusionTileWidth: Int
    public var diffusionTileHeight: Int
    public var diffusionTileOverlap: Int

    // MARK: - Upscaler

    public var upscaler: String?
    public var upscalerScaleFactor: Int

    // MARK: - Face restoration

    public var faceRestoration: String?

    // MARK: - Refiner

    public var refinerModel: String?
    public var refinerStart: Double

    // MARK: - Inpainting

    public var maskBlur: Double
    public var maskBlurOutset: Double
    public var preserveOriginalAfterInpaint: Bool

    // MARK: - Crop / original image size

    public var cropLeft: Int
    public var cropTop: Int
    public var originalImageWidth: Int
    public var originalImageHeight: Int
    public var negativeOriginalImageWidth: Int
    public var negativeOriginalImageHeight: Int
    public var targetImageWidth: Int
    public var targetImageHeight: Int

    // MARK: - Compression artifacts

    public var compressionArtifacts: String
    public var compressionArtifactsQuality: Double

    // MARK: - Shift

    public var shift: Double
    public var resolutionDependentShift: Bool

    // MARK: - Stage 2 (cascade / multi-stage)

    public var stage2Guidance: Double
    public var stage2Shift: Double
    public var stage2Steps: Int
    public var startFrameGuidance: Double

    // MARK: - Video / animation

    public var fps: Int
    public var numFrames: Int
    public var motionScale: Int
    public var guidingFrameNoise: Double

    // MARK: - TeaCache

    public var teaCache: Bool
    public var teaCacheStart: Double
    public var teaCacheEnd: Double
    public var teaCacheThreshold: Double
    public var teaCacheMaxSkipSteps: Int

    // MARK: - Causal inference

    public var causalInference: Double
    public var causalInferencePad: Int

    // MARK: - Misc

    public var id: Int

    // MARK: - LoRAs and Controls

    public var loras: [LoRAConfiguration]
    public var controls: [JSONValue]

    // MARK: - Overflow bucket (architecture rule 4)

    /// Keys present in the source JSON that this model doesn't have typed
    /// properties for. Re-encoded verbatim on output so future/unknown
    /// fields are never dropped.
    public var overflow: [String: JSONValue]
}
