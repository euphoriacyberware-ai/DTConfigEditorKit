/// A single LoRA entry in a Draw Things configuration.
///
/// `mode` is an open pass-through string (e.g. "all", "unet", "text_encoder")
/// rather than a closed enum, so unrecognized future values decode successfully.
public struct LoRAConfiguration: Sendable, Equatable {
    public var file: String
    public var weight: Double
    public var mode: String
    public var overflow: [String: JSONValue]

    public init(file: String, weight: Double = 1.0, mode: String = "all", overflow: [String: JSONValue] = [:]) {
        self.file = file
        self.weight = weight
        self.mode = mode
        self.overflow = overflow
    }
}
