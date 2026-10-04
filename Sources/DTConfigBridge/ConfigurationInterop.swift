import DTConfigCore
import DrawThingsClient
import Foundation

public enum EmitStyle: Sendable {
    case full
    case nonDefaultOnly
    case preserveShape(keys: Set<String>)
}

/// Converts between editor text and `DrawThingsConfiguration`, using DrawThingsClient's
/// `Codable` conformance as the single source of truth for Draw Things JSON.
public enum ConfigurationInterop {

    // MARK: - Parse (text -> struct)

    public static func configuration(from text: String) -> DrawThingsConfiguration? {
        let result = Parser.parse(text)
        return configuration(from: result)
    }

    public static func configuration(from result: ParseResult) -> DrawThingsConfiguration? {
        guard let json = result.value else { return nil }
        return configuration(from: json)
    }

    /// Decodes a configuration. Missing keys take `DrawThingsConfiguration()` defaults; a key
    /// whose value has the wrong type is skipped (the validator reports it) rather than failing
    /// the whole document. Returns nil when the value is not an object or has no `model`.
    public static func configuration(from json: JSONValue) -> DrawThingsConfiguration? {
        guard case .object(let pairs) = json else { return nil }
        let members = lastValuePerKey(pairs)
            .filter { knownKeys.contains($0.key) }
            .map { (key: $0.key, value: normalizingLegacyValue($0.value, forKey: $0.key)) }
        guard let model = members.first(where: { $0.key == "model" })?.value,
              case .string(let name) = model, !name.isEmpty
        else { return nil }

        if let config = try? DrawThingsConfiguration.fromJSON(serializeValue(.object(members))) {
            return config
        }
        let decodable = members.filter { member in
            (try? DrawThingsConfiguration.fromJSON(serializeValue(.object([member])))) != nil
        }
        return try? DrawThingsConfiguration.fromJSON(serializeValue(.object(decodable)))
    }

    public static func unknownKeys(from text: String) -> [(String, JSONValue)] {
        let result = Parser.parse(text)
        return unknownKeys(from: result)
    }

    public static func unknownKeys(from result: ParseResult) -> [(String, JSONValue)] {
        guard let json = result.value ?? result.valueRecovered,
              case .object(let pairs) = json else { return [] }
        return pairs.filter { !knownKeys.contains($0.key) }
    }

    public static func configurationAndUnknownKeys(
        from text: String
    ) -> (DrawThingsConfiguration?, [(String, JSONValue)]) {
        let result = Parser.parse(text)
        return configurationAndUnknownKeys(from: result)
    }

    public static func configurationAndUnknownKeys(
        from result: ParseResult
    ) -> (DrawThingsConfiguration?, [(String, JSONValue)]) {
        let unknown = unknownKeys(from: result)
        guard let json = result.value else { return (nil, unknown) }
        return (configuration(from: json), unknown)
    }

    // MARK: - Emit (struct -> text)

    public static func text(
        from config: DrawThingsConfiguration,
        style: EmitStyle = .nonDefaultOnly,
        unknownKeys: [(String, JSONValue)] = []
    ) -> String {
        var pairs = encodedPairs(config)

        switch style {
        case .full:
            break
        case .nonDefaultOnly:
            pairs = pairs.filter { key, value in
                if key == "model" { return true }
                guard let defaultValue = defaultValues[key] else { return true }
                return !numericEqual(value, defaultValue)
            }
        case .preserveShape(let keys):
            pairs = pairs.filter { keys.contains($0.key) }
            if !pairs.contains(where: { $0.key == "model" }) {
                pairs.insert((key: "model", value: .string(config.model)), at: 0)
            }
        }

        for (key, value) in unknownKeys where !pairs.contains(where: { $0.key == key }) {
            pairs.append((key: key, value: value))
        }

        pairs.sort { $0.key < $1.key }
        return emitJSON(pairs)
    }

    // MARK: - Known keys

    /// Every top-level key DrawThingsClient reads, derived from its encoder so it can't drift,
    /// plus `causalInferenceEnabled`, which older editors wrote (now implied by `causalInference > 0`).
    public static let knownKeys: Set<String> = {
        var probe = DrawThingsConfiguration()
        // Keys written only when set.
        probe.name = "name"
        probe.t5Text = "t5Text"
        probe.enableInpainting = true
        return Set(encodedPairs(probe).map(\.key)).union(["causalInferenceEnabled"])
    }()

    /// `DrawThingsConfiguration()` as JSON values: the values a missing key decodes to.
    public static let defaultValues: [String: JSONValue] = Dictionary(
        encodedPairs(DrawThingsConfiguration()).map { ($0.key, $0.value) },
        uniquingKeysWith: { _, last in last })

    private static func encodedPairs(_ config: DrawThingsConfiguration) -> [(key: String, value: JSONValue)] {
        guard let json = try? config.toJSON(),
              case .object(let pairs)? = Parser.parse(json).value
        else { return [(key: "model", value: .string(config.model))] }
        return pairs
    }

    /// Older editors wrote some enums as integers; DrawThingsClient only reads their names.
    private static func normalizingLegacyValue(_ value: JSONValue, forKey key: String) -> JSONValue {
        switch (key, value) {
        case ("compressionArtifacts", .int(let raw)):
            guard let method = Int8(raw).flatMap(CompressionMethod.init(rawValue:)) else { return value }
            switch method {
            case .disabled: return .string("disabled")
            case .h264: return .string("h264")
            case .h265: return .string("h265")
            case .jpeg: return .string("jpeg")
            }
        case ("colorCalibration", .int(let raw)):
            guard let calibration = Int8(raw).flatMap(ColorCalibration.init(rawValue:)) else { return value }
            switch calibration {
            case .disabled: return .string("none")
            case .lab: return .string("lab")
            }
        case ("controls", .array(let controls)):
            return .array(controls.map { control in
                guard case .object(let members) = control else { return control }
                return .object(members.map { member in
                    guard member.key == "controlImportance", case .int(let raw) = member.value,
                          let mode = Int8(raw).flatMap(ControlMode.init(rawValue:))
                    else { return member }
                    switch mode {
                    case .balanced: return (key: member.key, value: .string("balanced"))
                    case .prompt: return (key: member.key, value: .string("prompt"))
                    case .control: return (key: member.key, value: .string("control"))
                    }
                })
            })
        default:
            return value
        }
    }

    private static func lastValuePerKey(
        _ pairs: [(key: String, value: JSONValue)]
    ) -> [(key: String, value: JSONValue)] {
        var seen = Set<String>()
        return pairs.reversed().filter { seen.insert($0.key).inserted }.reversed()
    }

    // MARK: - JSON emission

    private static func emitJSON(_ pairs: [(key: String, value: JSONValue)]) -> String {
        if pairs.isEmpty { return "{}" }
        var lines: [String] = ["{"]
        for (i, pair) in pairs.enumerated() {
            let comma = i < pairs.count - 1 ? "," : ""
            lines.append("  \(JSONString.quote(pair.key)): \(serializeValue(pair.value, indent: 1))\(comma)")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    static func serializeValue(_ value: JSONValue, indent: Int = 0) -> String {
        switch value {
        case .null: return "null"
        case .bool(true): return "true"
        case .bool(false): return "false"
        case .int(let s): return s
        case .float(let s): return s
        case .string(let s): return JSONString.quote(s)
        case .array(let elements):
            if elements.isEmpty { return "[]" }
            let inner = String(repeating: "  ", count: indent + 1)
            let outer = String(repeating: "  ", count: indent)
            let items = elements.map { "\(inner)\(serializeValue($0, indent: indent + 1))" }
            return "[\n\(items.joined(separator: ",\n"))\n\(outer)]"
        case .object(let pairs):
            if pairs.isEmpty { return "{}" }
            let inner = String(repeating: "  ", count: indent + 1)
            let outer = String(repeating: "  ", count: indent)
            let items = pairs.map {
                "\(inner)\(JSONString.quote($0.key)): \(serializeValue($0.value, indent: indent + 1))"
            }
            return "{\n\(items.joined(separator: ",\n"))\n\(outer)}"
        }
    }

    static func numericEqual(_ a: JSONValue, _ b: JSONValue) -> Bool {
        switch (a, b) {
        case (.null, .null): return true
        case (.bool(let x), .bool(let y)): return x == y
        case (.string(let x), .string(let y)): return x == y
        case (.int(let x), .int(let y)): return Int(x) == Int(y)
        case (.float(let x), .float(let y)),
             (.int(let x), .float(let y)),
             (.float(let x), .int(let y)):
            return Double(x) == Double(y)
        case (.array(let x), .array(let y)):
            guard x.count == y.count else { return false }
            return zip(x, y).allSatisfy { numericEqual($0, $1) }
        case (.object(let x), .object(let y)):
            guard x.count == y.count else { return false }
            return zip(x, y).allSatisfy { $0.key == $1.key && numericEqual($0.value, $1.value) }
        default:
            return false
        }
    }
}
