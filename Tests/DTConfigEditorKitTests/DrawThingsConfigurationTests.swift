import Testing
import Foundation
@testable import DTConfigEditorKit

@Suite("DrawThingsConfiguration parsing")
struct DrawThingsConfigurationTests {

    /// Load the basic-config.json fixture from the test bundle.
    private func loadFixture() throws -> Data {
        guard let url = Bundle.module.url(forResource: "basic-config", withExtension: "json", subdirectory: "Fixtures") else {
            Issue.record("Fixture basic-config.json not found in test bundle")
            return Data()
        }
        return try Data(contentsOf: url)
    }

    @Test func decodesFixtureWithoutError() throws {
        let data = try loadFixture()
        _ = try DrawThingsConfiguration(jsonData: data)
    }

    @Test func fixtureGenerationParameters() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())

        #expect(config.model == "z_image_turbo_1.0_q8p.ckpt")
        #expect(config.sampler == 17)
        #expect(config.steps == 8)
        #expect(config.guidanceScale == 1)
        #expect(config.seed == 2_980_573_769)
        #expect(config.seedMode == 2)
        #expect(config.strength == 1)
        #expect(config.batchCount == 1)
        #expect(config.batchSize == 1)
        #expect(config.width == 1024)
        #expect(config.height == 1024)
    }

    @Test func fixtureAestheticAndQuality() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())

        #expect(config.aestheticScore == 6)
        #expect(config.negativeAestheticScore == 2.5)
        #expect(config.sharpness == 0)
        #expect(config.clipSkip == 1)
        #expect(config.clipWeight == 1)
    }

    @Test func fixtureNullableStringFields() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())

        #expect(config.clipLText == nil)
        #expect(config.openClipGText == nil)
        #expect(config.faceRestoration == nil)
        #expect(config.refinerModel == nil)
        #expect(config.upscaler == nil)
    }

    @Test func fixtureBooleanFields() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())

        #expect(config.cfgZeroStar == false)
        #expect(config.hiresFix == false)
        #expect(config.tiledDecoding == false)
        #expect(config.tiledDiffusion == false)
        #expect(config.separateClipL == false)
        #expect(config.separateOpenClipG == false)
        #expect(config.separateT5 == false)
        #expect(config.t5TextEncoder == true)
        #expect(config.speedUpWithGuidanceEmbed == true)
        #expect(config.negativePromptForImagePrior == true)
        #expect(config.preserveOriginalAfterInpaint == true)
        #expect(config.zeroNegativePrompt == false)
        #expect(config.teaCache == false)
        #expect(config.resolutionDependentShift == false)
    }

    @Test func fixtureGuidanceAndEmbeddings() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())

        #expect(config.guidanceEmbed == 3.5)
        #expect(config.imageGuidanceScale == 1.5)
        #expect(config.imagePriorSteps == 5)
        #expect(config.stochasticSamplingGamma == 0.3)
    }

    @Test func fixtureTileSettings() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())

        #expect(config.decodingTileWidth == 640)
        #expect(config.decodingTileHeight == 640)
        #expect(config.decodingTileOverlap == 128)
        #expect(config.diffusionTileWidth == 1024)
        #expect(config.diffusionTileHeight == 1024)
        #expect(config.diffusionTileOverlap == 128)
    }

    @Test func fixtureHiresFixSettings() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())

        #expect(config.hiresFixWidth == 448)
        #expect(config.hiresFixHeight == 448)
        #expect(config.hiresFixStrength == 0.7)
    }

    @Test func fixtureVideoAndAnimation() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())

        #expect(config.fps == 5)
        #expect(config.numFrames == 14)
        #expect(config.motionScale == 127)
        #expect(config.guidingFrameNoise == 0.02)
    }

    @Test func fixtureTeaCacheSettings() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())

        #expect(config.teaCacheStart == 5)
        #expect(config.teaCacheEnd == -1)
        #expect(config.teaCacheThreshold == 0.2)
        #expect(config.teaCacheMaxSkipSteps == 3)
    }

    @Test func fixtureShiftAndStage2() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())

        #expect(config.shift == 3)
        #expect(config.stage2Guidance == 1)
        #expect(config.stage2Shift == 1)
        #expect(config.stage2Steps == 10)
        #expect(config.startFrameGuidance == 1)
    }

    @Test func fixtureLoRAs() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())

        #expect(config.loras.count == 1)
        let lora = config.loras[0]
        #expect(lora.file == "zit_natalie_illustrated_lora_f16.ckpt")
        #expect(lora.weight == 0.6)
        #expect(lora.mode == "all")
        #expect(lora.overflow.isEmpty)
    }

    @Test func fixtureControls() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())
        #expect(config.controls.isEmpty)
    }

    @Test func fixtureOverflowIsEmpty() throws {
        let config = try DrawThingsConfiguration(jsonData: loadFixture())
        #expect(config.overflow.isEmpty, "All fixture keys should be known — overflow should be empty")
    }

    // MARK: - Step 3: Null/empty-string normalization

    @Test func nullableFieldsNormalizeNullToNil() throws {
        let json = """
        {"upscaler": null, "faceRestoration": null, "refinerModel": null, "clipLText": null, "openClipGText": null}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))

        #expect(config.upscaler == nil)
        #expect(config.faceRestoration == nil)
        #expect(config.refinerModel == nil)
        #expect(config.clipLText == nil)
        #expect(config.openClipGText == nil)
    }

    @Test func nullableFieldsNormalizeEmptyStringToNil() throws {
        let json = """
        {"upscaler": "", "faceRestoration": "", "refinerModel": "", "clipLText": "", "openClipGText": ""}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))

        #expect(config.upscaler == nil)
        #expect(config.faceRestoration == nil)
        #expect(config.refinerModel == nil)
        #expect(config.clipLText == nil)
        #expect(config.openClipGText == nil)
    }

    @Test func nullableFieldsPreserveNonEmptyValues() throws {
        let json = """
        {"upscaler": "RealESRGAN", "faceRestoration": "CodeFormer", "refinerModel": "sd_xl_refiner.ckpt", "clipLText": "a photo", "openClipGText": "detailed"}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))

        #expect(config.upscaler == "RealESRGAN")
        #expect(config.faceRestoration == "CodeFormer")
        #expect(config.refinerModel == "sd_xl_refiner.ckpt")
        #expect(config.clipLText == "a photo")
        #expect(config.openClipGText == "detailed")
    }

    @Test func nullableFieldsMixedRepresentations() throws {
        let json = """
        {"upscaler": null, "faceRestoration": "", "refinerModel": "model.ckpt", "clipLText": null, "openClipGText": ""}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))

        #expect(config.upscaler == nil)
        #expect(config.faceRestoration == nil)
        #expect(config.refinerModel == "model.ckpt")
        #expect(config.clipLText == nil)
        #expect(config.openClipGText == nil)
    }

    // MARK: - Overflow & round-trip

    @Test func unknownKeysGoToOverflow() throws {
        let json = """
        {"model": "test.ckpt", "sampler": 0, "steps": 20, "futureField": 42, "anotherNew": "hello"}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))

        #expect(config.model == "test.ckpt")
        #expect(config.overflow.count == 2)
        #expect(config.overflow["futureField"] == .int(42))
        #expect(config.overflow["anotherNew"] == .string("hello"))
    }

    @Test func roundTripDecodeEncodeDecodeCompare() throws {
        let original = try DrawThingsConfiguration(jsonData: loadFixture())
        let reEncoded = try original.jsonData()
        let decoded = try DrawThingsConfiguration(jsonData: reEncoded)

        #expect(decoded == original)
    }

    @Test func overflowKeysPreservedOnRoundTrip() throws {
        let json = """
        {"model": "test.ckpt", "unknownField": [1, 2, 3], "nested": {"a": true}}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        let reEncoded = try config.jsonData()
        let roundTripped = try DrawThingsConfiguration(jsonData: reEncoded)

        #expect(roundTripped.overflow["unknownField"] == .array([.int(1), .int(2), .int(3)]))
        #expect(roundTripped.overflow["nested"] == .object(["a": .bool(true)]))
    }
}
