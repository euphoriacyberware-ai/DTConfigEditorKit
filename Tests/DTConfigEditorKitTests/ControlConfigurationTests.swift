import Testing
import Foundation
@testable import DTConfigEditorKit

@Suite("ControlConfiguration")
struct ControlConfigurationTests {

    // MARK: - Parsing from config JSON

    @Test func parseSingleControl() throws {
        let json = """
        {"controls": [{"file": "canny.safetensors", "weight": 0.8, "guidanceStart": 0.0, "guidanceEnd": 1.0, "controlImportance": "balanced"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))

        #expect(config.controls.count == 1)
        let ctrl = config.controls[0]
        #expect(ctrl.file == "canny.safetensors")
        #expect(ctrl.weight == 0.8)
        #expect(ctrl.guidanceStart == 0.0)
        #expect(ctrl.guidanceEnd == 1.0)
        #expect(ctrl.controlImportance == "balanced")
    }

    @Test func parseMultipleControls() throws {
        let json = """
        {"controls": [
            {"file": "canny.safetensors", "weight": 1.0, "guidanceStart": 0.0, "guidanceEnd": 0.5, "controlImportance": "prompt"},
            {"file": "depth.safetensors", "weight": 0.6, "guidanceStart": 0.2, "guidanceEnd": 0.8, "controlImportance": "control"}
        ]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))

        #expect(config.controls.count == 2)
        #expect(config.controls[0].file == "canny.safetensors")
        #expect(config.controls[0].controlImportance == "prompt")
        #expect(config.controls[1].file == "depth.safetensors")
        #expect(config.controls[1].guidanceStart == 0.2)
        #expect(config.controls[1].guidanceEnd == 0.8)
    }

    @Test func parseEmptyControlsArray() throws {
        let json = """
        {"controls": []}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.controls.isEmpty)
    }

    @Test func missingControlsArrayDefaultsToEmpty() throws {
        let json = """
        {"model": "test.ckpt"}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.controls.isEmpty)
    }

    // MARK: - Open/pass-through controlImportance (rule 6)

    @Test func unrecognizedControlImportanceDecodesSuccessfully() throws {
        let json = """
        {"controls": [{"file": "ctrl.ckpt", "weight": 1.0, "guidanceStart": 0, "guidanceEnd": 1, "controlImportance": "future_importance_mode"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.controls[0].controlImportance == "future_importance_mode")
    }

    // MARK: - Defaults for missing fields

    @Test func missingWeightDefaultsToOne() throws {
        let json = """
        {"controls": [{"file": "ctrl.ckpt", "guidanceStart": 0, "guidanceEnd": 1, "controlImportance": "balanced"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.controls[0].weight == 1.0)
    }

    @Test func missingGuidanceStartDefaultsToZero() throws {
        let json = """
        {"controls": [{"file": "ctrl.ckpt", "weight": 1.0, "guidanceEnd": 1, "controlImportance": "balanced"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.controls[0].guidanceStart == 0.0)
    }

    @Test func missingGuidanceEndDefaultsToOne() throws {
        let json = """
        {"controls": [{"file": "ctrl.ckpt", "weight": 1.0, "guidanceStart": 0, "controlImportance": "balanced"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.controls[0].guidanceEnd == 1.0)
    }

    @Test func missingControlImportanceDefaultsToBalanced() throws {
        let json = """
        {"controls": [{"file": "ctrl.ckpt", "weight": 1.0, "guidanceStart": 0, "guidanceEnd": 1}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.controls[0].controlImportance == "balanced")
    }

    @Test func missingFileDefaultsToEmpty() throws {
        let json = """
        {"controls": [{"weight": 1.0, "guidanceStart": 0, "guidanceEnd": 1, "controlImportance": "balanced"}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        #expect(config.controls[0].file == "")
    }

    // MARK: - Overflow / unknown fields (rule 4)

    @Test func unknownControlFieldsGoToOverflow() throws {
        let json = """
        {"controls": [{"file": "ctrl.ckpt", "weight": 1.0, "guidanceStart": 0, "guidanceEnd": 1, "controlImportance": "balanced", "preprocessor": "canny", "resolution": 512}]}
        """
        let config = try DrawThingsConfiguration(jsonData: Data(json.utf8))

        let ctrl = config.controls[0]
        #expect(ctrl.file == "ctrl.ckpt")
        #expect(ctrl.overflow.count == 2)
        #expect(ctrl.overflow["preprocessor"] == .string("canny"))
        #expect(ctrl.overflow["resolution"] == .int(512))
    }

    // MARK: - Round-trip

    @Test func roundTripPreservesControls() throws {
        let json = """
        {"controls": [
            {"file": "canny.safetensors", "weight": 0.8, "guidanceStart": 0.1, "guidanceEnd": 0.9, "controlImportance": "prompt"},
            {"file": "depth.safetensors", "weight": 0.5, "guidanceStart": 0.0, "guidanceEnd": 1.0, "controlImportance": "control"}
        ]}
        """
        let original = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        let reEncoded = try original.jsonData()
        let decoded = try DrawThingsConfiguration(jsonData: reEncoded)

        #expect(decoded.controls == original.controls)
    }

    @Test func roundTripPreservesControlOverflow() throws {
        let json = """
        {"controls": [{"file": "ctrl.ckpt", "weight": 1.0, "guidanceStart": 0, "guidanceEnd": 1, "controlImportance": "balanced", "futureField": {"nested": true}}]}
        """
        let original = try DrawThingsConfiguration(jsonData: Data(json.utf8))
        let reEncoded = try original.jsonData()
        let decoded = try DrawThingsConfiguration(jsonData: reEncoded)

        #expect(decoded.controls[0].overflow["futureField"] == .object(["nested": .bool(true)]))
    }

    // MARK: - Fixture validation

    @Test func fixtureHasEmptyControls() throws {
        guard let url = Bundle.module.url(forResource: "basic-config", withExtension: "json", subdirectory: "Fixtures") else {
            Issue.record("Fixture not found")
            return
        }
        let config = try DrawThingsConfiguration(jsonData: Data(contentsOf: url))
        #expect(config.controls.isEmpty)
    }
}
