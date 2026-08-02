/// String-keyed `WritableKeyPath` dictionaries for every scalar field on
/// `DrawThingsConfiguration`, grouped by value type.
///
/// These let the UI layer create dynamic bindings from `FieldDescriptor.key`
/// without a giant switch statement.
extension DrawThingsConfiguration {

    nonisolated(unsafe) static let boolKeyPaths: [String: WritableKeyPath<DrawThingsConfiguration, Bool>] = [
        "cfgZeroStar": \.cfgZeroStar,
        "hiresFix": \.hiresFix,
        "negativePromptForImagePrior": \.negativePromptForImagePrior,
        "preserveOriginalAfterInpaint": \.preserveOriginalAfterInpaint,
        "resolutionDependentShift": \.resolutionDependentShift,
        "separateClipL": \.separateClipL,
        "separateOpenClipG": \.separateOpenClipG,
        "separateT5": \.separateT5,
        "speedUpWithGuidanceEmbed": \.speedUpWithGuidanceEmbed,
        "t5TextEncoder": \.t5TextEncoder,
        "teaCache": \.teaCache,
        "tiledDecoding": \.tiledDecoding,
        "tiledDiffusion": \.tiledDiffusion,
        "zeroNegativePrompt": \.zeroNegativePrompt,
    ]

    nonisolated(unsafe) static let intKeyPaths: [String: WritableKeyPath<DrawThingsConfiguration, Int>] = [
        "batchCount": \.batchCount,
        "batchSize": \.batchSize,
        "causalInferencePad": \.causalInferencePad,
        "cfgZeroInitSteps": \.cfgZeroInitSteps,
        "clipSkip": \.clipSkip,
        "cropLeft": \.cropLeft,
        "cropTop": \.cropTop,
        "decodingTileHeight": \.decodingTileHeight,
        "decodingTileOverlap": \.decodingTileOverlap,
        "decodingTileWidth": \.decodingTileWidth,
        "diffusionTileHeight": \.diffusionTileHeight,
        "diffusionTileOverlap": \.diffusionTileOverlap,
        "diffusionTileWidth": \.diffusionTileWidth,
        "fps": \.fps,
        "height": \.height,
        "hiresFixHeight": \.hiresFixHeight,
        "hiresFixWidth": \.hiresFixWidth,
        "id": \.id,
        "imagePriorSteps": \.imagePriorSteps,
        "motionScale": \.motionScale,
        "negativeOriginalImageHeight": \.negativeOriginalImageHeight,
        "negativeOriginalImageWidth": \.negativeOriginalImageWidth,
        "numFrames": \.numFrames,
        "originalImageHeight": \.originalImageHeight,
        "originalImageWidth": \.originalImageWidth,
        "sampler": \.sampler,
        "seed": \.seed,
        "seedMode": \.seedMode,
        "stage2Steps": \.stage2Steps,
        "steps": \.steps,
        "targetImageHeight": \.targetImageHeight,
        "targetImageWidth": \.targetImageWidth,
        "teaCacheMaxSkipSteps": \.teaCacheMaxSkipSteps,
        "upscalerScaleFactor": \.upscalerScaleFactor,
        "width": \.width,
    ]

    nonisolated(unsafe) static let doubleKeyPaths: [String: WritableKeyPath<DrawThingsConfiguration, Double>] = [
        "aestheticScore": \.aestheticScore,
        "causalInference": \.causalInference,
        "clipWeight": \.clipWeight,
        "compressionArtifactsQuality": \.compressionArtifactsQuality,
        "guidanceEmbed": \.guidanceEmbed,
        "guidanceScale": \.guidanceScale,
        "guidingFrameNoise": \.guidingFrameNoise,
        "hiresFixStrength": \.hiresFixStrength,
        "imageGuidanceScale": \.imageGuidanceScale,
        "maskBlur": \.maskBlur,
        "maskBlurOutset": \.maskBlurOutset,
        "negativeAestheticScore": \.negativeAestheticScore,
        "refinerStart": \.refinerStart,
        "sharpness": \.sharpness,
        "shift": \.shift,
        "stage2Guidance": \.stage2Guidance,
        "stage2Shift": \.stage2Shift,
        "startFrameGuidance": \.startFrameGuidance,
        "stochasticSamplingGamma": \.stochasticSamplingGamma,
        "strength": \.strength,
        "teaCacheEnd": \.teaCacheEnd,
        "teaCacheStart": \.teaCacheStart,
        "teaCacheThreshold": \.teaCacheThreshold,
    ]

    nonisolated(unsafe) static let stringKeyPaths: [String: WritableKeyPath<DrawThingsConfiguration, String>] = [
        "compressionArtifacts": \.compressionArtifacts,
        "model": \.model,
    ]

    nonisolated(unsafe) static let optionalStringKeyPaths: [String: WritableKeyPath<DrawThingsConfiguration, String?>] = [
        "clipLText": \.clipLText,
        "faceRestoration": \.faceRestoration,
        "openClipGText": \.openClipGText,
        "refinerModel": \.refinerModel,
        "upscaler": \.upscaler,
    ]
}
