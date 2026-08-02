import Testing
import Foundation
@testable import DTConfigEditorKit

@Suite("LoRAConfiguration")
struct LoRAConfigurationTests {

    // MARK: - Parsing from config JSON

    @Test func parseSingleLoRA() throws {
        let json = """
        {"loras": [{"file": "my_lora.ckpt", "weight": 0.8, "mode": "all"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))

        #expect(config.loras.count == 1)
        #expect(config.loras[0].file == "my_lora.ckpt")
        #expect(config.loras[0].weight == 0.8)
        #expect(config.loras[0].mode == "all")
    }

    @Test func parseMultipleLoRAs() throws {
        let json = """
        {"loras": [
            {"file": "style.safetensors", "weight": 0.6, "mode": "all"},
            {"file": "detail.ckpt", "weight": 1.0, "mode": "unet"},
            {"file": "face.safetensors", "weight": 0.3, "mode": "text_encoder"}
        ]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))

        #expect(config.loras.count == 3)
        #expect(config.loras[0].file == "style.safetensors")
        #expect(config.loras[1].file == "detail.ckpt")
        #expect(config.loras[1].mode == "unet")
        #expect(config.loras[2].file == "face.safetensors")
        #expect(config.loras[2].mode == "text_encoder")
    }

    @Test func parseEmptyLoRAArray() throws {
        let json = """
        {"loras": []}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.loras.isEmpty)
    }

    @Test func missingLoRAArrayDefaultsToEmpty() throws {
        let json = """
        {"model": "test.ckpt"}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.loras.isEmpty)
    }

    // MARK: - Open/pass-through mode (rule 6)

    @Test func unrecognizedModeDecodesSuccessfully() throws {
        let json = """
        {"loras": [{"file": "lora.ckpt", "weight": 1.0, "mode": "some_future_mode"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.loras[0].mode == "some_future_mode")
    }

    // MARK: - Defaults for missing fields

    @Test func missingWeightDefaultsToOne() throws {
        let json = """
        {"loras": [{"file": "lora.ckpt", "mode": "all"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.loras[0].weight == 1.0)
    }

    @Test func missingModeDefaultsToAll() throws {
        let json = """
        {"loras": [{"file": "lora.ckpt", "weight": 0.5}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.loras[0].mode == "all")
    }

    @Test func missingFileDefaultsToEmpty() throws {
        let json = """
        {"loras": [{"weight": 0.5, "mode": "all"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.loras[0].file == "")
    }

    // MARK: - Overflow / unknown fields (rule 4)

    @Test func unknownLoRAFieldsGoToOverflow() throws {
        let json = """
        {"loras": [{"file": "lora.ckpt", "weight": 0.8, "mode": "all", "newParam": true, "version": 2}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))

        let lora = config.loras[0]
        #expect(lora.file == "lora.ckpt")
        #expect(lora.overflow.count == 2)
        #expect(lora.overflow["newParam"] == .bool(true))
        #expect(lora.overflow["version"] == .int(2))
    }

    // MARK: - Round-trip

    @Test func roundTripPreservesLoRAs() throws {
        let json = """
        {"loras": [
            {"file": "style.safetensors", "weight": 0.6, "mode": "unet"},
            {"file": "detail.ckpt", "weight": 1.0, "mode": "all"}
        ]}
        """
        let original = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        let reEncoded = try original.jsonData()
        let decoded = try DrawThingsConfiguration(jsonData: reEncoded)

        #expect(decoded.loras == original.loras)
    }

    @Test func roundTripPreservesLoRAOverflow() throws {
        let json = """
        {"loras": [{"file": "lora.ckpt", "weight": 0.8, "mode": "all", "futureKey": [1, 2]}]}
        """
        let original = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        let reEncoded = try original.jsonData()
        let decoded = try DrawThingsConfiguration(jsonData: reEncoded)

        #expect(decoded.loras[0].overflow["futureKey"] == .array([.int(1), .int(2)]))
    }

    // MARK: - Weight edge cases

    @Test func negativeWeight() throws {
        let json = """
        {"loras": [{"file": "lora.ckpt", "weight": -0.5, "mode": "all"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.loras[0].weight == -0.5)
    }

    @Test func zeroWeight() throws {
        let json = """
        {"loras": [{"file": "lora.ckpt", "weight": 0, "mode": "all"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.loras[0].weight == 0)
    }
}
