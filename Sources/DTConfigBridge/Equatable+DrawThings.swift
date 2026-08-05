import DrawThingsClient

extension LoRAConfig: @retroactive Equatable {
    public static func == (lhs: LoRAConfig, rhs: LoRAConfig) -> Bool {
        lhs.file == rhs.file &&
        lhs.weight == rhs.weight &&
        lhs.mode.rawValue == rhs.mode.rawValue
    }
}

extension ControlConfig: @retroactive Equatable {
    public static func == (lhs: ControlConfig, rhs: ControlConfig) -> Bool {
        lhs.file == rhs.file &&
        lhs.weight == rhs.weight &&
        lhs.guidanceStart == rhs.guidanceStart &&
        lhs.guidanceEnd == rhs.guidanceEnd &&
        lhs.controlMode.rawValue == rhs.controlMode.rawValue
    }
}

extension DrawThingsConfiguration: @retroactive Equatable {
    public static func == (lhs: DrawThingsConfiguration, rhs: DrawThingsConfiguration) -> Bool {
        lhs.model == rhs.model &&
        lhs.width == rhs.width &&
        lhs.height == rhs.height &&
        lhs.steps == rhs.steps &&
        lhs.sampler.rawValue == rhs.sampler.rawValue &&
        lhs.guidanceScale == rhs.guidanceScale &&
        lhs.seed == rhs.seed &&
        lhs.clipSkip == rhs.clipSkip &&
        lhs.shift == rhs.shift &&
        lhs.loras == rhs.loras &&
        lhs.controls == rhs.controls &&
        lhs.batchCount == rhs.batchCount &&
        lhs.batchSize == rhs.batchSize &&
        lhs.strength == rhs.strength &&
        lhs.imageGuidanceScale == rhs.imageGuidanceScale &&
        lhs.clipWeight == rhs.clipWeight &&
        lhs.guidanceEmbed == rhs.guidanceEmbed &&
        lhs.speedUpWithGuidanceEmbed == rhs.speedUpWithGuidanceEmbed &&
        lhs.cfgZeroStar == rhs.cfgZeroStar &&
        lhs.cfgZeroInitSteps == rhs.cfgZeroInitSteps &&
        lhs.compressionArtifacts.rawValue == rhs.compressionArtifacts.rawValue &&
        lhs.compressionArtifactsQuality == rhs.compressionArtifactsQuality &&
        lhs.colorCalibration.rawValue == rhs.colorCalibration.rawValue &&
        lhs.expandPromptToJson == rhs.expandPromptToJson &&
        lhs.maskBlur == rhs.maskBlur &&
        lhs.maskBlurOutset == rhs.maskBlurOutset &&
        lhs.preserveOriginalAfterInpaint == rhs.preserveOriginalAfterInpaint &&
        lhs.enableInpainting == rhs.enableInpainting &&
        lhs.sharpness == rhs.sharpness &&
        lhs.stochasticSamplingGamma == rhs.stochasticSamplingGamma &&
        lhs.aestheticScore == rhs.aestheticScore &&
        lhs.negativeAestheticScore == rhs.negativeAestheticScore &&
        lhs.negativePromptForImagePrior == rhs.negativePromptForImagePrior &&
        lhs.imagePriorSteps == rhs.imagePriorSteps &&
        lhs.cropTop == rhs.cropTop &&
        lhs.cropLeft == rhs.cropLeft &&
        lhs.originalImageHeight == rhs.originalImageHeight &&
        lhs.originalImageWidth == rhs.originalImageWidth &&
        lhs.targetImageHeight == rhs.targetImageHeight &&
        lhs.targetImageWidth == rhs.targetImageWidth &&
        lhs.negativeOriginalImageHeight == rhs.negativeOriginalImageHeight &&
        lhs.negativeOriginalImageWidth == rhs.negativeOriginalImageWidth &&
        lhs.upscalerScaleFactor == rhs.upscalerScaleFactor &&
        lhs.resolutionDependentShift == rhs.resolutionDependentShift &&
        lhs.t5TextEncoder == rhs.t5TextEncoder &&
        lhs.separateClipL == rhs.separateClipL &&
        lhs.separateOpenClipG == rhs.separateOpenClipG &&
        lhs.separateT5 == rhs.separateT5 &&
        lhs.tiledDiffusion == rhs.tiledDiffusion &&
        lhs.diffusionTileWidth == rhs.diffusionTileWidth &&
        lhs.diffusionTileHeight == rhs.diffusionTileHeight &&
        lhs.diffusionTileOverlap == rhs.diffusionTileOverlap &&
        lhs.tiledDecoding == rhs.tiledDecoding &&
        lhs.decodingTileWidth == rhs.decodingTileWidth &&
        lhs.decodingTileHeight == rhs.decodingTileHeight &&
        lhs.decodingTileOverlap == rhs.decodingTileOverlap &&
        lhs.hiresFix == rhs.hiresFix &&
        lhs.hiresFixWidth == rhs.hiresFixWidth &&
        lhs.hiresFixHeight == rhs.hiresFixHeight &&
        lhs.hiresFixStrength == rhs.hiresFixStrength &&
        lhs.stage2Steps == rhs.stage2Steps &&
        lhs.stage2Guidance == rhs.stage2Guidance &&
        lhs.stage2Shift == rhs.stage2Shift &&
        lhs.teaCache == rhs.teaCache &&
        lhs.teaCacheStart == rhs.teaCacheStart &&
        lhs.teaCacheEnd == rhs.teaCacheEnd &&
        lhs.teaCacheThreshold == rhs.teaCacheThreshold &&
        lhs.teaCacheMaxSkipSteps == rhs.teaCacheMaxSkipSteps &&
        lhs.causalInferenceEnabled == rhs.causalInferenceEnabled &&
        lhs.causalInference == rhs.causalInference &&
        lhs.causalInferencePad == rhs.causalInferencePad &&
        lhs.fps == rhs.fps &&
        lhs.motionScale == rhs.motionScale &&
        lhs.guidingFrameNoise == rhs.guidingFrameNoise &&
        lhs.startFrameGuidance == rhs.startFrameGuidance &&
        lhs.numFrames == rhs.numFrames &&
        lhs.refinerModel == rhs.refinerModel &&
        lhs.refinerStart == rhs.refinerStart &&
        lhs.zeroNegativePrompt == rhs.zeroNegativePrompt &&
        lhs.upscaler == rhs.upscaler &&
        lhs.faceRestoration == rhs.faceRestoration &&
        lhs.name == rhs.name &&
        lhs.clipLText == rhs.clipLText &&
        lhs.openClipGText == rhs.openClipGText &&
        lhs.t5Text == rhs.t5Text &&
        lhs.seedMode == rhs.seedMode
    }
}
