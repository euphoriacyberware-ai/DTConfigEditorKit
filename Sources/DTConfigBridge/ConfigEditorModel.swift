import DTConfigCore
import DrawThingsClient
import Observation

@Observable
@MainActor
public final class ConfigEditorModel: ConfigTextEditing {
    public var text: String {
        didSet { textDidChange() }
    }
    public private(set) var diagnostics: [Diagnostic] = []
    public private(set) var configuration: DrawThingsConfiguration?
    public private(set) var unknownKeys: [(String, JSONValue)] = []

    public var isValid: Bool { configuration != nil }

    public var currentParseResult: ParseResult? { parseResult }

    private var parseResult: ParseResult?
    private var validationTask: Task<Void, Never>?

    // MARK: - Init

    public init(_ configuration: DrawThingsConfiguration, style: EmitStyle = .nonDefaultOnly) {
        self.text = ConfigurationInterop.text(from: configuration, style: style)
        self.configuration = configuration
        reparse()
    }

    public init(text: String) {
        self.text = text
        reparse()
    }

    // MARK: - Surgical edit

    /// Replace a single top-level key's value in the text, touching only that key's byte span.
    /// Falls back to full re-emission when the document is unparseable.
    public func set(_ key: String, to value: JSONValue) {
        guard let result = parseResult,
              let objectNode = ModelFamilyDetector.findRootObject(result.root)
        else {
            // Unparseable: fall back to full re-emission
            if var config = configuration {
                applyToConfig(&config, key: key, value: value)
                text = ConfigurationInterop.text(
                    from: config, style: .full, unknownKeys: unknownKeys)
            }
            return
        }

        // Find existing member
        for member in objectNode.children
            where member.kind == .member && member.children.count >= 2
        {
            let keyNode = member.children[0]
            let valueNode = member.children[1]
            guard let memberKey = ModelFamilyDetector.extractKey(keyNode, tokens: result.tokens),
                  memberKey == key,
                  valueNode.kind != .error
            else { continue }

            // Replace value byte range
            let serialized = ConfigurationInterop.serializeValue(value)
            var utf8 = Array(text.utf8)
            let range = valueNode.byteRange
            utf8.replaceSubrange(range, with: Array(serialized.utf8))
            text = String(decoding: utf8, as: UTF8.self)
            return
        }

        // Key not found: insert before closing brace
        insertMember(key: key, value: value, in: objectNode, tokens: result.tokens)
    }

    // MARK: - Private

    private func reparse() {
        let result = Parser.parse(text)
        self.parseResult = result
        let (config, unknown) = ConfigurationInterop.configurationAndUnknownKeys(from: result)
        self.configuration = config
        self.unknownKeys = unknown
        scheduleValidation()
    }

    private func textDidChange() {
        reparse()
    }

    private func scheduleValidation() {
        validationTask?.cancel()
        let result = self.parseResult
        let modelName = extractModelName()
        validationTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            guard let result else {
                self.diagnostics = []
                return
            }
            var diags = Validator.validate(result)
            if let name = modelName {
                diags += ModelFamilyDetector.inertDiagnostics(
                    parseResult: result, modelName: name)
            }
            diags.sort { $0.range.lowerBound < $1.range.lowerBound }
            self.diagnostics = diags
        }
    }

    private func extractModelName() -> String? {
        guard let result = parseResult,
              let json = result.value ?? result.valueRecovered,
              case .object(let pairs) = json,
              let modelPair = pairs.first(where: { $0.key == "model" }),
              case .string(let name) = modelPair.value,
              !name.isEmpty
        else { return nil }
        return name
    }

    private func insertMember(
        key: String, value: JSONValue,
        in objectNode: CSTNode, tokens: [Token]
    ) {
        // Find closing brace position
        var braceBytePos: Int?
        for i in stride(
            from: objectNode.tokenRange.upperBound - 1,
            through: objectNode.tokenRange.lowerBound, by: -1
        ) {
            guard i < tokens.count else { continue }
            if tokens[i].kind == .rightBrace {
                braceBytePos = tokens[i].range.lowerBound
                break
            }
        }
        guard let insertPos = braceBytePos else { return }

        let hasMembers = objectNode.children.contains { $0.kind == .member }
        let serialized = ConfigurationInterop.serializeValue(value)
        let insertion: String
        if hasMembers {
            insertion = ", \"\(key)\": \(serialized)"
        } else {
            insertion = "\"\(key)\": \(serialized)"
        }

        var utf8 = Array(text.utf8)
        utf8.insert(contentsOf: Array(insertion.utf8), at: insertPos)
        text = String(decoding: utf8, as: UTF8.self)
    }

    private func applyToConfig(
        _ config: inout DrawThingsConfiguration, key: String, value: JSONValue
    ) {
        switch key {
        case "width": if let v = value.asInt32 { config.width = v }
        case "height": if let v = value.asInt32 { config.height = v }
        case "steps": if let v = value.asInt32 { config.steps = v }
        case "model": if let v = value.asString { config.model = v }
        case "guidanceScale": if let v = value.asFloat { config.guidanceScale = v }
        case "seed":
            config.seed = value.asInt64
        case "shift": if let v = value.asFloat { config.shift = v }
        case "strength": if let v = value.asFloat { config.strength = v }
        case "sampler":
            if let raw = value.asInt32, let s = SamplerType(rawValue: Int8(raw)) {
                config.sampler = s
            }
        default: break // other fields can be added as needed
        }
    }
}
