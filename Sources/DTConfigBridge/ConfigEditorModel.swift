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
    /// Falls back to full re-emission when the document has no root object.
    public func set(_ key: String, to value: JSONValue) {
        guard let result = parseResult,
              let objectNode = result.findRootObject()
        else {
            if var config = configuration {
                let member = JSONValue.object([(key: key, value: value)])
                try? config.mergeJSON(ConfigurationInterop.serializeValue(member))
                text = ConfigurationInterop.text(
                    from: config, style: .full, unknownKeys: unknownKeys)
            }
            return
        }

        // Replace the value of an existing member
        for member in objectNode.children
            where member.kind == .member && member.children.count >= 2
        {
            let valueNode = member.children[1]
            guard result.extractKey(from: member.children[0]) == key,
                  valueNode.kind != .error
            else { continue }

            var utf8 = Array(text.utf8)
            let range = valueNode.byteRange.clamped(to: 0..<utf8.count)
            utf8.replaceSubrange(range, with: Array(ConfigurationInterop.serializeValue(value).utf8))
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
        let member = "\(JSONString.quote(key)): \(ConfigurationInterop.serializeValue(value))"
        let insertion = hasMembers ? ", \(member)" : member

        var utf8 = Array(text.utf8)
        guard insertPos <= utf8.count else { return }
        utf8.insert(contentsOf: Array(insertion.utf8), at: insertPos)
        text = String(decoding: utf8, as: UTF8.self)
    }
}
