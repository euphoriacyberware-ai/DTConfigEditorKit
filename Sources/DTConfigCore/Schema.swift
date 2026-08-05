public struct FieldPath: Sendable, Hashable {
    public let components: [String]

    public init(_ components: String...) {
        self.components = components
    }

    public init(_ components: [String]) {
        self.components = components
    }

    public func appending(_ component: String) -> FieldPath {
        FieldPath(components + [component])
    }

    public static let model = FieldPath("model")
    public static let upscaler = FieldPath("upscaler")
    public static let loraFile = FieldPath("loras", "file")
    public static let controlFile = FieldPath("controls", "file")
}

public struct DomainValue: Sendable {
    public let value: String
    public let label: String?

    public init(value: String, label: String? = nil) {
        self.value = value
        self.label = label
    }
}

public enum FieldType: Sendable {
    case bool
    case int
    case float
    case string
    case nullableString
    case nullableInt
    case intEnum(name: String, range: ClosedRange<Int>, labels: [Int: String])
    case stringOrIntEnum(name: String, strings: [String], intRange: ClosedRange<Int>)
    indirect case array(FieldSchema)
    indirect case object(ObjectSchema)
    case stringArray
}

public struct FieldSchema: Sendable {
    public let type: FieldType
    public let jsonDefault: JSONValue?
    public let multipleOf64: Bool
    public let label: String?
    public let doc: String?
    public let domainPath: FieldPath?

    public init(
        type: FieldType,
        jsonDefault: JSONValue? = nil,
        multipleOf64: Bool = false,
        label: String? = nil,
        doc: String? = nil,
        domainPath: FieldPath? = nil
    ) {
        self.type = type
        self.jsonDefault = jsonDefault
        self.multipleOf64 = multipleOf64
        self.label = label
        self.doc = doc
        self.domainPath = domainPath
    }
}

public struct ObjectSchema: Sendable {
    public let fields: [String: FieldSchema]

    public init(fields: [String: FieldSchema]) {
        self.fields = fields
    }
}
