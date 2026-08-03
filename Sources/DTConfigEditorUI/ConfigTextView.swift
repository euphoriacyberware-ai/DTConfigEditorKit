import SwiftUI
import DTConfigCore

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - ConfigTextView

/// A TextKit 2 editor surface for Draw Things configuration JSON.
///
/// Generic over any `ConfigTextEditing & Observable` model so that
/// DTConfigBridge (and its DrawThingsClient dependency) stays out
/// of this target.
///
/// Syntax highlighting is applied through rendering attributes on
/// `NSTextLayoutManager` — the text storage is never mutated for
/// decoration, preserving undo and typing attributes.
#if os(macOS)
public struct ConfigTextView<Model: ConfigTextEditing & Observable>: NSViewRepresentable {
    public var model: Model
    @Environment(\.colorScheme) private var colorScheme

    public init(model: Model) {
        self.model = model
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.string = model.text
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        let coordinator = context.coordinator
        let theme = EditorTheme.resolved(for: colorScheme)

        textView.backgroundColor = NSColor(theme.background)
        textView.insertionPointColor = NSColor(theme.foreground)

        // Sync text only for external model changes (e.g. set(_:to:)).
        if textView.string != model.text {
            let sel = textView.selectedRanges
            textView.string = model.text
            let maxLen = (textView.string as NSString).length
            textView.selectedRanges = sel.map { v in
                let r = v.rangeValue
                let loc = min(r.location, maxLen)
                return NSValue(range: NSRange(location: loc,
                                              length: min(r.length, maxLen - loc)))
            }
        }

        coordinator.applyDecorations(
            textView: textView,
            text: model.text,
            parseResult: model.currentParseResult,
            diagnostics: model.diagnostics,
            theme: theme
        )
    }

    public func makeCoordinator() -> TextViewCoordinator {
        TextViewCoordinator(model: model)
    }
}

#else // iOS

public struct ConfigTextView<Model: ConfigTextEditing & Observable>: UIViewRepresentable {
    public var model: Model
    @Environment(\.colorScheme) private var colorScheme

    public init(model: Model) {
        self.model = model
    }

    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(usingTextLayoutManager: true)
        textView.isEditable = true
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.delegate = context.coordinator
        textView.text = model.text
        return textView
    }

    public func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        let theme = EditorTheme.resolved(for: colorScheme)

        textView.backgroundColor = UIColor(theme.background)
        textView.tintColor = UIColor(theme.foreground)

        if textView.text != model.text {
            let sel = textView.selectedRange
            textView.text = model.text
            let maxLen = (textView.text as NSString).length
            let loc = min(sel.location, maxLen)
            textView.selectedRange = NSRange(location: loc,
                                             length: min(sel.length, maxLen - loc))
        }

        coordinator.applyDecorations(
            textView: textView,
            text: model.text,
            parseResult: model.currentParseResult,
            diagnostics: model.diagnostics,
            theme: theme
        )
    }

    public func makeCoordinator() -> TextViewCoordinator {
        TextViewCoordinator(model: model)
    }
}
#endif

// MARK: - Shared Coordinator (non-generic for @objc delegate conformance)

@MainActor
public final class TextViewCoordinator: NSObject {
    let model: any ConfigTextEditing

    init(model: any ConfigTextEditing) {
        self.model = model
        super.init()
    }

    // MARK: - Decoration (cross-platform)

    #if os(macOS)
    func applyDecorations(
        textView: NSTextView,
        text: String,
        parseResult: ParseResult?,
        diagnostics: [Diagnostic],
        theme: EditorTheme
    ) {
        guard let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return }
        applyDecorations(
            layoutManager: layoutManager,
            contentManager: contentManager,
            text: text,
            parseResult: parseResult,
            diagnostics: diagnostics,
            theme: theme
        )
    }
    #else
    func applyDecorations(
        textView: UITextView,
        text: String,
        parseResult: ParseResult?,
        diagnostics: [Diagnostic],
        theme: EditorTheme
    ) {
        guard let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return }
        applyDecorations(
            layoutManager: layoutManager,
            contentManager: contentManager,
            text: text,
            parseResult: parseResult,
            diagnostics: diagnostics,
            theme: theme
        )
    }
    #endif

    private func applyDecorations(
        layoutManager: NSTextLayoutManager,
        contentManager: NSTextContentManager,
        text: String,
        parseResult: ParseResult?,
        diagnostics: [Diagnostic],
        theme: EditorTheme
    ) {
        let offsetTable = OffsetTable(text)
        let docRange = contentManager.documentRange

        // Clear previous rendering attributes.
        layoutManager.removeRenderingAttribute(.foregroundColor, for: docRange)
        layoutManager.removeRenderingAttribute(.underlineStyle, for: docRange)
        layoutManager.removeRenderingAttribute(.underlineColor, for: docRange)

        // Syntax highlighting from the parse tree.
        let spans = parseResult?.syntaxSpans() ?? []
        for span in spans {
            guard let textRange = Self.textRange(
                for: span.byteRange, offsetTable: offsetTable, contentManager: contentManager
            ) else { continue }
            layoutManager.addRenderingAttribute(
                .foregroundColor,
                value: Self.platformColor(theme.color(for: span.role)),
                for: textRange
            )
        }

        // Diagnostic decoration.
        for diagnostic in diagnostics {
            guard !diagnostic.range.isEmpty,
                  let textRange = Self.textRange(
                    for: diagnostic.range, offsetTable: offsetTable,
                    contentManager: contentManager
                  )
            else { continue }

            switch diagnostic.severity {
            case .error:
                layoutManager.addRenderingAttribute(
                    .underlineStyle,
                    value: NSUnderlineStyle.thick.rawValue,
                    for: textRange
                )
                layoutManager.addRenderingAttribute(
                    .underlineColor,
                    value: Self.platformColor(theme.errorUnderline),
                    for: textRange
                )
            case .warning:
                layoutManager.addRenderingAttribute(
                    .underlineStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    for: textRange
                )
                layoutManager.addRenderingAttribute(
                    .underlineColor,
                    value: Self.platformColor(theme.warningUnderline),
                    for: textRange
                )
            case .inert:
                layoutManager.addRenderingAttribute(
                    .foregroundColor,
                    value: Self.platformColor(theme.inertText),
                    for: textRange
                )
            }
        }
    }

    // MARK: - Helpers

    private static func textRange(
        for byteRange: Range<Int>,
        offsetTable: OffsetTable,
        contentManager: NSTextContentManager
    ) -> NSTextRange? {
        let utf16 = offsetTable.utf16Range(forByteRange: byteRange)
        let docStart = contentManager.documentRange.location
        guard let start = contentManager.location(docStart, offsetBy: utf16.lowerBound),
              let end = contentManager.location(docStart, offsetBy: utf16.upperBound)
        else { return nil }
        return NSTextRange(location: start, end: end)
    }

    private static func platformColor(_ color: Color) -> Any {
        #if os(macOS)
        NSColor(color)
        #else
        UIColor(color)
        #endif
    }
}

// MARK: - Delegate conformance

#if os(macOS)
extension TextViewCoordinator: NSTextViewDelegate {
    public func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        model.text = textView.string
    }
}
#else
extension TextViewCoordinator: UITextViewDelegate {
    public func textViewDidChange(_ textView: UITextView) {
        model.text = textView.text
    }
}
#endif
