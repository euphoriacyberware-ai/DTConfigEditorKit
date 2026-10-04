import DTConfigCore

/// Drives a ``ConfigTextView`` from outside it: menus, toolbars, a problems list.
///
/// Edits made through these actions go through the text view, so each is a single undoable
/// step. Assigning `model.text` directly instead replaces the text and clears undo history,
/// which suits loading a new document.
///
/// Pass the same instance to `ConfigTextView(model:actions:)`. Each method returns false
/// when no text view is attached yet.
@MainActor
public final class ConfigEditorActions {
    weak var coordinator: TextViewCoordinator?

    public init() {}

    /// Whether a text view is attached.
    public var isAttached: Bool { coordinator != nil }

    @discardableResult
    public func formatDocument() -> Bool {
        guard let coordinator else { return false }
        coordinator.formatDocument()
        return true
    }

    @discardableResult
    public func sortDocumentKeys() -> Bool {
        guard let coordinator else { return false }
        coordinator.sortDocumentKeys()
        return true
    }

    @discardableResult
    public func applyFixIt(_ fixIt: FixIt) -> Bool {
        guard let coordinator else { return false }
        coordinator.applyFixIt(fixIt)
        return true
    }

    /// Replace the whole document as one undoable edit.
    @discardableResult
    public func replaceText(with text: String) -> Bool {
        guard let coordinator else { return false }
        coordinator.replaceText(with: text)
        return true
    }

    /// Select and scroll to a byte range, e.g. a diagnostic's.
    @discardableResult
    public func select(_ range: Range<Int>) -> Bool {
        guard let coordinator else { return false }
        coordinator.selectRange(range)
        return true
    }
}
