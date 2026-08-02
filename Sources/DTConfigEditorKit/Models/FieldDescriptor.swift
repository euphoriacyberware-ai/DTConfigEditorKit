/// The UI section a configuration field belongs to.
public enum FieldSection: String, Sendable, Equatable, CaseIterable {
    case generation          = "Generation"
    case aestheticQuality    = "Aesthetic / Quality"
    case guidanceEmbeddings  = "Guidance & Embeddings"
    case cfgZero             = "CFG-Zero"
    case textEncoders        = "Text Encoders"
    case hiresFix            = "Hires Fix"
    case tiledProcessing     = "Tiled Processing"
    case upscaler            = "Upscaler"
    case faceRestoration     = "Face Restoration"
    case refiner             = "Refiner"
    case inpainting          = "Inpainting"
    case imageSize           = "Image Size"
    case compressionArtifacts = "Compression Artifacts"
    case shift               = "Shift"
    case stage2              = "Stage 2"
    case videoAnimation      = "Video / Animation"
    case teaCache            = "TeaCache"
    case causalInference     = "Causal Inference"
    case misc                = "Misc"
}

/// Hint for the UI about what control to render for a field.
///
/// These are categories, not strict bindings — the SwiftUI layer may
/// choose a Stepper, Slider, or TextField for a given `integerField`
/// depending on the field's typical range.
public enum FieldControlType: String, Sendable, Equatable {
    case toggle          // Bool
    case integerField    // Int (stepper, picker, or text input)
    case decimalField    // Double (slider or text input)
    case textField       // String
    case optionalText    // String? (nullable)
    case readOnly        // display-only (e.g. id)
}

/// Metadata describing a single configuration field for UI rendering.
public struct FieldDescriptor: Sendable, Equatable {
    /// The JSON key / property name on `DrawThingsConfiguration`.
    public let key: String
    /// Human-readable label for the UI.
    public let label: String
    /// Which section this field belongs to.
    public let section: FieldSection
    /// What kind of control to render.
    public let controlType: FieldControlType

    public init(key: String, label: String, section: FieldSection, controlType: FieldControlType) {
        self.key = key
        self.label = label
        self.section = section
        self.controlType = controlType
    }
}
