public enum JSONValue: Sendable {
    case null
    case bool(Bool)
    case int(String)
    case float(String)
    case string(String)
    case array([JSONValue])
    case object([(key: String, value: JSONValue)])
}

extension JSONValue: Equatable {
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null):
            return true
        case let (.bool(a), .bool(b)):
            return a == b
        case let (.int(a), .int(b)):
            return a == b
        case let (.float(a), .float(b)):
            return a == b
        case let (.string(a), .string(b)):
            return a == b
        case let (.array(a), .array(b)):
            return a == b
        case let (.object(a), .object(b)):
            guard a.count == b.count else { return false }
            for (pairA, pairB) in zip(a, b) {
                if pairA.key != pairB.key || pairA.value != pairB.value {
                    return false
                }
            }
            return true
        default:
            return false
        }
    }
}

extension JSONValue: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .null:
            hasher.combine(0)
        case let .bool(v):
            hasher.combine(1)
            hasher.combine(v)
        case let .int(v):
            hasher.combine(2)
            hasher.combine(v)
        case let .float(v):
            hasher.combine(3)
            hasher.combine(v)
        case let .string(v):
            hasher.combine(4)
            hasher.combine(v)
        case let .array(v):
            hasher.combine(5)
            hasher.combine(v)
        case let .object(pairs):
            hasher.combine(6)
            for pair in pairs {
                hasher.combine(pair.key)
                hasher.combine(pair.value)
            }
        }
    }
}
