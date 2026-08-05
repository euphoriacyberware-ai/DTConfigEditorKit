public enum Severity: String, Sendable, Equatable, Codable {
    case error
    case warning
    case inert
}

public struct FixIt: Sendable, Equatable {
    public let range: Range<Int>
    public let replacement: String
    public let label: String

    public init(range: Range<Int>, replacement: String, label: String) {
        self.range = range
        self.replacement = replacement
        self.label = label
    }
}

extension FixIt: Codable {
    enum CodingKeys: String, CodingKey {
        case range, replacement, label
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let r = try container.decode([Int].self, forKey: .range)
        guard r.count == 2 else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [CodingKeys.range], debugDescription: "Expected 2-element array for range"))
        }
        self.range = r[0]..<r[1]
        self.replacement = try container.decode(String.self, forKey: .replacement)
        self.label = try container.decode(String.self, forKey: .label)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode([range.lowerBound, range.upperBound], forKey: .range)
        try container.encode(replacement, forKey: .replacement)
        try container.encode(label, forKey: .label)
    }
}

public struct Diagnostic: Sendable, Equatable {
    public let range: Range<Int>
    public let severity: Severity
    public let code: String
    public let message: String
    public let fixIts: [FixIt]

    public init(
        range: Range<Int>,
        severity: Severity,
        code: String,
        message: String,
        fixIts: [FixIt] = []
    ) {
        self.range = range
        self.severity = severity
        self.code = code
        self.message = message
        self.fixIts = fixIts
    }
}

extension Diagnostic: Codable {
    enum CodingKeys: String, CodingKey {
        case range, severity, code, message, fixIts
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let r = try container.decode([Int].self, forKey: .range)
        guard r.count == 2 else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [CodingKeys.range], debugDescription: "Expected 2-element array for range"))
        }
        self.range = r[0]..<r[1]
        self.severity = try container.decode(Severity.self, forKey: .severity)
        self.code = try container.decode(String.self, forKey: .code)
        self.message = try container.decode(String.self, forKey: .message)
        self.fixIts = try container.decode([FixIt].self, forKey: .fixIts)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode([range.lowerBound, range.upperBound], forKey: .range)
        try container.encode(severity, forKey: .severity)
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
        try container.encode(fixIts, forKey: .fixIts)
    }
}
