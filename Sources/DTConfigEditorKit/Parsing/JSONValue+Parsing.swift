import Foundation

// MARK: - JSONSerialization-based parsing (accurate type detection)

extension JSONValue {

    /// Parse raw JSON data into a `JSONValue` tree.
    ///
    /// Uses `JSONSerialization` + `CFBooleanGetTypeID` to correctly
    /// distinguish JSON booleans from integers — something that
    /// Foundation's `Codable` layer conflates via `NSNumber` bridging.
    public static func parse(from data: Data) throws -> JSONValue {
        let obj = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        return try convert(obj)
    }

    /// Convert a Foundation JSON object tree into `JSONValue`.
    static func convert(_ value: Any) throws -> JSONValue {
        switch value {
        case is NSNull:
            return .null
        case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID():
            return .bool(number.boolValue)
        case let number as NSNumber:
            if let int = Int(exactly: number) {
                return .int(int)
            }
            return .double(number.doubleValue)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(try array.map { try convert($0) })
        case let dict as [String: Any]:
            return .object(try dict.mapValues { try convert($0) })
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Unsupported JSON type: \(type(of: value))")
            )
        }
    }

    /// Serialize this value back to JSON data.
    public func serialized(options: JSONSerialization.WritingOptions = []) throws -> Data {
        try JSONSerialization.data(withJSONObject: toFoundation(), options: options)
    }

    /// Convert to a Foundation-compatible JSON object tree for serialization.
    func toFoundation() -> Any {
        switch self {
        case .null:             return NSNull()
        case .bool(let v):      return v
        case .int(let v):       return v
        case .double(let v):    return v
        case .string(let v):    return v
        case .array(let arr):   return arr.map { $0.toFoundation() }
        case .object(let dict): return dict.mapValues { $0.toFoundation() }
        }
    }
}

// MARK: - Codable conformance

extension JSONValue: Codable {

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:             try container.encodeNil()
        case .bool(let v):      try container.encode(v)
        case .int(let v):       try container.encode(v)
        case .double(let v):    try container.encode(v)
        case .string(let v):    try container.encode(v)
        case .array(let v):     try container.encode(v)
        case .object(let v):    try container.encode(v)
        }
    }
}
