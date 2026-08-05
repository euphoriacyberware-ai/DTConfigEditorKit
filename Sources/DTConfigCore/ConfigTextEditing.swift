/// Protocol for the text-editing model consumed by DTConfigEditorUI.
///
/// Defined in DTConfigCore so the view target needs no dependency on DTConfigBridge
/// (which pulls DrawThingsClient and its heavy gRPC / SwiftNIO transitive graph).
///
/// Conforming types are expected to be `@Observable @MainActor` — the view adds
/// those constraints at the generic site rather than in this protocol, since
/// DTConfigCore imports nothing.
@MainActor
public protocol ConfigTextEditing: AnyObject {
    /// The full document text. The view writes to this on every keystroke;
    /// the model reparses and updates ``diagnostics`` / ``currentParseResult``.
    var text: String { get set }

    /// Current diagnostics for the document, updated after validation.
    var diagnostics: [Diagnostic] { get }

    /// The most recent parse result — tokens + CST. Used by the view
    /// to compute syntax spans for highlighting.  `nil` only before the
    /// first parse (i.e. never in practice, since init reparses).
    var currentParseResult: ParseResult? { get }
}
