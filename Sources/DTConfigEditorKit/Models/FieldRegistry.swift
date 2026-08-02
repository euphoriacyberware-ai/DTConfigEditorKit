/// Static registry of every known field in `DrawThingsConfiguration`,
/// ordered for UI display and grouped by section.
///
/// LoRA and Control entries are excluded — they have their own array-based
/// sub-editors and don't appear as top-level scalar fields.
public enum FieldRegistry {

    /// All field descriptors in display order.
    public static let descriptors: [FieldDescriptor] = [

        // MARK: Generation
        .init(key: "model",          label: "Model",          section: .generation, controlType: .textField),
        .init(key: "sampler",        label: "Sampler",        section: .generation, controlType: .integerField),
        .init(key: "steps",          label: "Steps",          section: .generation, controlType: .integerField),
        .init(key: "guidanceScale",  label: "Guidance Scale", section: .generation, controlType: .decimalField),
        .init(key: "seed",           label: "Seed",           section: .generation, controlType: .integerField),
        .init(key: "seedMode",       label: "Seed Mode",      section: .generation, controlType: .integerField),
        .init(key: "strength",       label: "Strength",       section: .generation, controlType: .decimalField),
        .init(key: "batchCount",     label: "Batch Count",    section: .generation, controlType: .integerField),
        .init(key: "batchSize",      label: "Batch Size",     section: .generation, controlType: .integerField),
        .init(key: "width",          label: "Width",          section: .generation, controlType: .integerField),
        .init(key: "height",         label: "Height",         section: .generation, controlType: .integerField),

        // MARK: Aesthetic / Quality
        .init(key: "aestheticScore",         label: "Aesthetic Score",          section: .aestheticQuality, controlType: .decimalField),
        .init(key: "negativeAestheticScore", label: "Negative Aesthetic Score", section: .aestheticQuality, controlType: .decimalField),
        .init(key: "sharpness",              label: "Sharpness",               section: .aestheticQuality, controlType: .decimalField),
        .init(key: "clipSkip",               label: "CLIP Skip",               section: .aestheticQuality, controlType: .integerField),
        .init(key: "clipWeight",             label: "CLIP Weight",             section: .aestheticQuality, controlType: .decimalField),

        // MARK: Guidance & Embeddings
        .init(key: "guidanceEmbed",              label: "Guidance Embed",                section: .guidanceEmbeddings, controlType: .decimalField),
        .init(key: "speedUpWithGuidanceEmbed",   label: "Speed Up with Guidance Embed",  section: .guidanceEmbeddings, controlType: .toggle),
        .init(key: "imageGuidanceScale",         label: "Image Guidance Scale",          section: .guidanceEmbeddings, controlType: .decimalField),
        .init(key: "imagePriorSteps",            label: "Image Prior Steps",             section: .guidanceEmbeddings, controlType: .integerField),
        .init(key: "negativePromptForImagePrior", label: "Negative Prompt for Image Prior", section: .guidanceEmbeddings, controlType: .toggle),
        .init(key: "stochasticSamplingGamma",    label: "Stochastic Sampling Gamma",     section: .guidanceEmbeddings, controlType: .decimalField),

        // MARK: CFG-Zero
        .init(key: "cfgZeroStar",      label: "CFG-Zero*",        section: .cfgZero, controlType: .toggle),
        .init(key: "cfgZeroInitSteps", label: "CFG-Zero Init Steps", section: .cfgZero, controlType: .integerField),

        // MARK: Text Encoders
        .init(key: "separateClipL",      label: "Separate CLIP-L",      section: .textEncoders, controlType: .toggle),
        .init(key: "clipLText",          label: "CLIP-L Text",          section: .textEncoders, controlType: .optionalText),
        .init(key: "separateOpenClipG",  label: "Separate OpenCLIP-G",  section: .textEncoders, controlType: .toggle),
        .init(key: "openClipGText",      label: "OpenCLIP-G Text",      section: .textEncoders, controlType: .optionalText),
        .init(key: "separateT5",         label: "Separate T5",          section: .textEncoders, controlType: .toggle),
        .init(key: "t5TextEncoder",      label: "T5 Text Encoder",      section: .textEncoders, controlType: .toggle),
        .init(key: "zeroNegativePrompt", label: "Zero Negative Prompt", section: .textEncoders, controlType: .toggle),

        // MARK: Hires Fix
        .init(key: "hiresFix",         label: "Hires Fix",          section: .hiresFix, controlType: .toggle),
        .init(key: "hiresFixWidth",    label: "Hires Fix Width",    section: .hiresFix, controlType: .integerField),
        .init(key: "hiresFixHeight",   label: "Hires Fix Height",   section: .hiresFix, controlType: .integerField),
        .init(key: "hiresFixStrength", label: "Hires Fix Strength", section: .hiresFix, controlType: .decimalField),

        // MARK: Tiled Processing
        .init(key: "tiledDecoding",       label: "Tiled Decoding",         section: .tiledProcessing, controlType: .toggle),
        .init(key: "decodingTileWidth",   label: "Decoding Tile Width",    section: .tiledProcessing, controlType: .integerField),
        .init(key: "decodingTileHeight",  label: "Decoding Tile Height",   section: .tiledProcessing, controlType: .integerField),
        .init(key: "decodingTileOverlap", label: "Decoding Tile Overlap",  section: .tiledProcessing, controlType: .integerField),
        .init(key: "tiledDiffusion",       label: "Tiled Diffusion",        section: .tiledProcessing, controlType: .toggle),
        .init(key: "diffusionTileWidth",   label: "Diffusion Tile Width",   section: .tiledProcessing, controlType: .integerField),
        .init(key: "diffusionTileHeight",  label: "Diffusion Tile Height",  section: .tiledProcessing, controlType: .integerField),
        .init(key: "diffusionTileOverlap", label: "Diffusion Tile Overlap", section: .tiledProcessing, controlType: .integerField),

        // MARK: Upscaler
        .init(key: "upscaler",            label: "Upscaler",            section: .upscaler, controlType: .optionalText),
        .init(key: "upscalerScaleFactor", label: "Upscaler Scale Factor", section: .upscaler, controlType: .integerField),

        // MARK: Face Restoration
        .init(key: "faceRestoration", label: "Face Restoration", section: .faceRestoration, controlType: .optionalText),

        // MARK: Refiner
        .init(key: "refinerModel", label: "Refiner Model", section: .refiner, controlType: .optionalText),
        .init(key: "refinerStart", label: "Refiner Start", section: .refiner, controlType: .decimalField),

        // MARK: Inpainting
        .init(key: "maskBlur",                    label: "Mask Blur",                      section: .inpainting, controlType: .decimalField),
        .init(key: "maskBlurOutset",               label: "Mask Blur Outset",               section: .inpainting, controlType: .decimalField),
        .init(key: "preserveOriginalAfterInpaint", label: "Preserve Original After Inpaint", section: .inpainting, controlType: .toggle),

        // MARK: Image Size
        .init(key: "cropLeft",                    label: "Crop Left",                     section: .imageSize, controlType: .integerField),
        .init(key: "cropTop",                     label: "Crop Top",                      section: .imageSize, controlType: .integerField),
        .init(key: "originalImageWidth",          label: "Original Image Width",           section: .imageSize, controlType: .integerField),
        .init(key: "originalImageHeight",         label: "Original Image Height",          section: .imageSize, controlType: .integerField),
        .init(key: "negativeOriginalImageWidth",  label: "Negative Original Image Width",  section: .imageSize, controlType: .integerField),
        .init(key: "negativeOriginalImageHeight", label: "Negative Original Image Height", section: .imageSize, controlType: .integerField),
        .init(key: "targetImageWidth",            label: "Target Image Width",             section: .imageSize, controlType: .integerField),
        .init(key: "targetImageHeight",           label: "Target Image Height",            section: .imageSize, controlType: .integerField),

        // MARK: Compression Artifacts
        .init(key: "compressionArtifacts",        label: "Compression Artifacts",         section: .compressionArtifacts, controlType: .textField),
        .init(key: "compressionArtifactsQuality", label: "Compression Artifacts Quality", section: .compressionArtifacts, controlType: .decimalField),

        // MARK: Shift
        .init(key: "shift",                    label: "Shift",                      section: .shift, controlType: .decimalField),
        .init(key: "resolutionDependentShift", label: "Resolution Dependent Shift", section: .shift, controlType: .toggle),

        // MARK: Stage 2
        .init(key: "stage2Guidance",     label: "Stage 2 Guidance",      section: .stage2, controlType: .decimalField),
        .init(key: "stage2Shift",        label: "Stage 2 Shift",         section: .stage2, controlType: .decimalField),
        .init(key: "stage2Steps",        label: "Stage 2 Steps",         section: .stage2, controlType: .integerField),
        .init(key: "startFrameGuidance", label: "Start Frame Guidance",  section: .stage2, controlType: .decimalField),

        // MARK: Video / Animation
        .init(key: "fps",               label: "FPS",                 section: .videoAnimation, controlType: .integerField),
        .init(key: "numFrames",          label: "Number of Frames",    section: .videoAnimation, controlType: .integerField),
        .init(key: "motionScale",        label: "Motion Scale",        section: .videoAnimation, controlType: .integerField),
        .init(key: "guidingFrameNoise",  label: "Guiding Frame Noise", section: .videoAnimation, controlType: .decimalField),

        // MARK: TeaCache
        .init(key: "teaCache",             label: "TeaCache",               section: .teaCache, controlType: .toggle),
        .init(key: "teaCacheStart",        label: "TeaCache Start",         section: .teaCache, controlType: .decimalField),
        .init(key: "teaCacheEnd",          label: "TeaCache End",           section: .teaCache, controlType: .decimalField),
        .init(key: "teaCacheThreshold",    label: "TeaCache Threshold",     section: .teaCache, controlType: .decimalField),
        .init(key: "teaCacheMaxSkipSteps", label: "TeaCache Max Skip Steps", section: .teaCache, controlType: .integerField),

        // MARK: Causal Inference
        .init(key: "causalInference",    label: "Causal Inference",     section: .causalInference, controlType: .decimalField),
        .init(key: "causalInferencePad", label: "Causal Inference Pad", section: .causalInference, controlType: .integerField),

        // MARK: Misc
        .init(key: "id", label: "ID", section: .misc, controlType: .readOnly),
    ]

    /// Look up a descriptor by its JSON key.
    public static let byKey: [String: FieldDescriptor] = {
        Dictionary(uniqueKeysWithValues: descriptors.map { ($0.key, $0) })
    }()

    /// All descriptors for a given section, in display order.
    public static func descriptors(for section: FieldSection) -> [FieldDescriptor] {
        descriptors.filter { $0.section == section }
    }

    /// Sections in display order (derived from the first appearance of each
    /// section in `descriptors`).
    public static let orderedSections: [FieldSection] = {
        var seen = Set<FieldSection>()
        var result: [FieldSection] = []
        for desc in descriptors {
            if seen.insert(desc.section).inserted {
                result.append(desc.section)
            }
        }
        return result
    }()
}
