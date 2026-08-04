/// Applies a ``FixIt`` to a source string, producing a new string with
/// only the target byte span changed. This is the same byte-level surgery
/// used by `ConfigEditorModel.set(_:to:)`.
public enum FixItApplicator {

    /// Replace the fix-it's byte range in `source` with its replacement text.
    public static func apply(_ fixIt: FixIt, to source: String) -> String {
        var bytes = Array(source.utf8)
        let lo = max(0, min(fixIt.range.lowerBound, bytes.count))
        let hi = max(lo, min(fixIt.range.upperBound, bytes.count))
        bytes.replaceSubrange(lo..<hi, with: Array(fixIt.replacement.utf8))
        return String(decoding: bytes, as: UTF8.self)
    }
}
