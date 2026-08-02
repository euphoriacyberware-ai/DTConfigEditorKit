/// A single ControlNet / control entry in a Draw Things configuration.
///
/// `controlImportance` is an open pass-through string (e.g. "balanced",
/// "prompt", "control") rather than a closed enum, so unrecognized future
/// values decode successfully (architecture rule 6).
public struct ControlConfiguration: Sendable, Equatable {
    public var file: String
    public var weight: Double
    public var guidanceStart: Double
    public var guidanceEnd: Double
    public var controlImportance: String
    public var overflow: [String: JSONValue]

    public init(
        file: String,
        weight: Double = 1.0,
        guidanceStart: Double = 0.0,
        guidanceEnd: Double = 1.0,
        controlImportance: String = "balanced",
        overflow: [String: JSONValue] = [:]
    ) {
        self.file = file
        self.weight = weight
        self.guidanceStart = guidanceStart
        self.guidanceEnd = guidanceEnd
        self.controlImportance = controlImportance
        self.overflow = overflow
    }
}
