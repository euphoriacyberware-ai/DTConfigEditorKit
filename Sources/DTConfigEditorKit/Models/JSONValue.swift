/// A generic, recursive representation of any JSON value.
///
/// Preserves type fidelity (bool vs int vs double) so that round-tripping
/// through decode-edit-encode never silently changes a value's JSON type.
public enum JSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}
