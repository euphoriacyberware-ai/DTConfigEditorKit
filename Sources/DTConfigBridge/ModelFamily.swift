import DTConfigCore
import DrawThingsClient

public enum ModelFamilyDetector {

    /// Video-specific fields that are inert on image models.
    /// Derived from SCHEMA.md section 4.4 and client `nativeFrameRate`.
    public static let videoInertFields: Set<String> = [
        "fps", "motionScale", "guidingFrameNoise", "startFrameGuidance",
        "numFrames", "causalInference", "causalInferencePad", "causalInferenceEnabled",
    ]

    public static func detect(from modelName: String) -> ModelFamily {
        ModelFamily.detect(from: modelName)
    }

    /// Returns field names that are inert for the given model.
    /// Currently only video fields on image models are marked inert.
    public static func inertFields(forModel modelName: String) -> Set<String> {
        let family = detect(from: modelName)
        if family.nativeFrameRate == nil {
            return videoInertFields
        }
        return []
    }

    /// Produce `.inert` diagnostics for video fields present in an image-model document.
    public static func inertDiagnostics(
        parseResult: ParseResult,
        modelName: String
    ) -> [Diagnostic] {
        let inert = inertFields(forModel: modelName)
        guard !inert.isEmpty else { return [] }

        guard let objectNode = parseResult.findRootObject() else { return [] }

        var diagnostics: [Diagnostic] = []
        for member in objectNode.children
            where member.kind == .member && member.children.count >= 2
        {
            let keyNode = member.children[0]
            guard let key = parseResult.extractKey(from: keyNode) else { continue }
            if inert.contains(key) {
                let removalRange = parseResult.memberRemovalRange(
                    forMemberAt: member.byteRange, in: objectNode)
                var fixIts: [FixIt] = []
                if let removal = removalRange {
                    fixIts.append(FixIt(
                        range: removal,
                        replacement: "",
                        label: "Remove \"\(key)\""))
                }
                diagnostics.append(Diagnostic(
                    range: member.byteRange,
                    severity: .inert,
                    code: "inert.video-field",
                    message: "\"\(key)\" is unused by image models",
                    fixIts: fixIts))
            }
        }
        return diagnostics
    }
}
