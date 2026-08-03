import DTConfigCore
import DrawThingsClient

public enum ModelFamilyDetector {

    /// Video-specific fields that are inert on image models.
    /// Derived from SCHEMA.md section 4.4 and client `nativeFrameRate`.
    public static let videoInertFields: Set<String> = [
        "fps", "motionScale", "guidingFrameNoise", "startFrameGuidance",
        "numFrames", "causalInference", "causalInferencePad", "causalInferenceEnabled",
    ]

    public static func detect(from modelName: String) -> LatentModelFamily {
        LatentModelFamily.detect(from: modelName)
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

        guard let objectNode = findRootObject(parseResult.root) else { return [] }

        var diagnostics: [Diagnostic] = []
        for member in objectNode.children
            where member.kind == .member && member.children.count >= 2
        {
            let keyNode = member.children[0]
            guard let key = extractKey(keyNode, tokens: parseResult.tokens) else { continue }
            if inert.contains(key) {
                diagnostics.append(Diagnostic(
                    range: member.byteRange,
                    severity: .inert,
                    code: "inert.video-field",
                    message: "\"\(key)\" is unused by image models"))
            }
        }
        return diagnostics
    }

    // MARK: - CST helpers (duplicated from Validator; these are private there)

    static func findRootObject(_ root: CSTNode) -> CSTNode? {
        for child in root.children where child.kind == .value {
            for grandchild in child.children where grandchild.kind == .object {
                return grandchild
            }
        }
        return nil
    }

    static func extractKey(_ node: CSTNode, tokens: [Token]) -> String? {
        for i in node.tokenRange where i < tokens.count {
            if tokens[i].kind == .string {
                return decodeString(tokens[i].text)
            }
        }
        return nil
    }

    static func decodeString(_ raw: String) -> String {
        guard raw.count >= 2, raw.hasPrefix("\"") else { return raw }
        if raw.hasSuffix("\"") {
            return String(raw.dropFirst().dropLast())
        }
        return String(raw.dropFirst())
    }
}
