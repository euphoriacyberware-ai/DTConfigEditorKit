import Testing
@testable import DTConfigEditorKit

@Suite("FieldRegistry")
struct FieldRegistryTests {

    // MARK: - Coverage

    @Test func allKnownKeysHaveDescriptors() {
        // Every key in DrawThingsConfiguration.knownKeys (except loras/controls,
        // which are array sub-editors) should have a registry entry.
        let arrayKeys: Set<String> = ["loras", "controls"]
        let registeredKeys = Set(FieldRegistry.descriptors.map(\.key))
        let scalarKnownKeys = DrawThingsConfiguration.knownKeys.subtracting(arrayKeys)

        let missing = scalarKnownKeys.subtracting(registeredKeys)
        #expect(missing.isEmpty, "Known keys missing from registry: \(missing.sorted())")
    }

    @Test func noExtraKeysInRegistry() {
        // Every registry key should correspond to an actual known key.
        let registeredKeys = Set(FieldRegistry.descriptors.map(\.key))
        let extra = registeredKeys.subtracting(DrawThingsConfiguration.knownKeys)
        #expect(extra.isEmpty, "Registry keys not in knownKeys: \(extra.sorted())")
    }

    @Test func noDuplicateKeys() {
        let keys = FieldRegistry.descriptors.map(\.key)
        let unique = Set(keys)
        #expect(keys.count == unique.count, "Duplicate keys in registry")
    }

    // MARK: - Lookup

    @Test func byKeyLookup() {
        let desc = FieldRegistry.byKey["steps"]
        #expect(desc != nil)
        #expect(desc?.label == "Steps")
        #expect(desc?.section == .generation)
        #expect(desc?.controlType == .integerField)
    }

    @Test func byKeyReturnsNilForUnknown() {
        #expect(FieldRegistry.byKey["nonexistent"] == nil)
    }

    // MARK: - Section grouping

    @Test func descriptorsForSectionFiltersCorrectly() {
        let cfgZeroFields = FieldRegistry.descriptors(for: .cfgZero)
        #expect(cfgZeroFields.count == 2)
        #expect(cfgZeroFields.allSatisfy { $0.section == .cfgZero })
    }

    @Test func everySectionHasAtLeastOneField() {
        for section in FieldSection.allCases {
            let fields = FieldRegistry.descriptors(for: section)
            #expect(!fields.isEmpty, "Section \(section.rawValue) has no fields")
        }
    }

    @Test func orderedSectionsMatchesCaseIterable() {
        let ordered = Set(FieldRegistry.orderedSections)
        let allCases = Set(FieldSection.allCases)
        #expect(ordered == allCases, "orderedSections should cover all FieldSection cases")
    }

    // MARK: - Control type consistency

    @Test func boolFieldsAreToggles() {
        let boolKeys: Set<String> = [
            "cfgZeroStar", "hiresFix", "tiledDecoding", "tiledDiffusion",
            "separateClipL", "separateOpenClipG", "separateT5",
            "t5TextEncoder", "speedUpWithGuidanceEmbed",
            "negativePromptForImagePrior", "preserveOriginalAfterInpaint",
            "zeroNegativePrompt", "teaCache", "resolutionDependentShift",
        ]
        for key in boolKeys {
            let desc = FieldRegistry.byKey[key]
            #expect(desc?.controlType == .toggle, "\(key) should be .toggle")
        }
    }

    @Test func nullableStringFieldsAreOptionalText() {
        let nullableKeys = ["clipLText", "openClipGText", "faceRestoration", "refinerModel", "upscaler"]
        for key in nullableKeys {
            let desc = FieldRegistry.byKey[key]
            #expect(desc?.controlType == .optionalText, "\(key) should be .optionalText")
        }
    }

    // MARK: - Labels

    @Test func labelsAreNonEmpty() {
        for desc in FieldRegistry.descriptors {
            #expect(!desc.label.isEmpty, "Label for \(desc.key) should not be empty")
        }
    }

    @Test func spotCheckLabels() {
        #expect(FieldRegistry.byKey["guidanceScale"]?.label == "Guidance Scale")
        #expect(FieldRegistry.byKey["cfgZeroStar"]?.label == "CFG-Zero*")
        #expect(FieldRegistry.byKey["t5TextEncoder"]?.label == "T5 Text Encoder")
        #expect(FieldRegistry.byKey["fps"]?.label == "FPS")
        #expect(FieldRegistry.byKey["id"]?.label == "ID")
    }
}
