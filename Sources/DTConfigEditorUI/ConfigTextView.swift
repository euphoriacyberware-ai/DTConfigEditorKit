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

    public func makeNSView(context: Context) -> NSView {
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

        context.coordinator.textView = textView

        // Add tracking area for hover-based diagnostic popovers.
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: context.coordinator,
            userInfo: nil
        )
        textView.addTrackingArea(trackingArea)

        // Build gutter as a plain NSView beside the scroll view (not NSRulerView,
        // which causes invisible text on macOS 26).
        let gutter = GutterSideView()
        gutter.textView = textView
        gutter.onGutterClick = { [weak coordinator = context.coordinator] line in
            coordinator?.handleGutterClick(line: line)
        }

        let container = NSView()
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        container.addSubview(gutter)
        container.addSubview(scrollView)

        // Layout via Auto Layout constraints.
        gutter.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let gutterWidth: CGFloat = gutter.gutterWidth
        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutter.topAnchor.constraint(equalTo: container.topAnchor),
            gutter.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutter.widthAnchor.constraint(equalToConstant: gutterWidth),

            scrollView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Observe scroll changes to redraw the gutter.
        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            gutter, selector: #selector(GutterSideView.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification, object: clipView)

        context.coordinator.gutterSideView = gutter

        return container
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        // Find the scroll view (first NSScrollView subview of the container).
        guard let scrollView = nsView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
              let textView = scrollView.documentView as? NSTextView
        else { return }

        let coordinator = context.coordinator
        let theme = EditorTheme.resolved(for: colorScheme)

        textView.backgroundColor = NSColor(theme.background)
        textView.textColor = NSColor(theme.foreground)
        textView.insertionPointColor = NSColor(theme.foreground)

        // Sync text only for external model changes (e.g. set(_:to:)).
        if !coordinator.isSyncing && textView.string != model.text {
            coordinator.isSyncing = true
            let sel = textView.selectedRanges
            textView.string = model.text
            let maxLen = (textView.string as NSString).length
            textView.selectedRanges = sel.map { v in
                let r = v.rangeValue
                let loc = min(r.location, maxLen)
                return NSValue(range: NSRange(location: loc,
                                              length: min(r.length, maxLen - loc)))
            }
            coordinator.isSyncing = false
        }

        coordinator.applyDecorations(
            textView: textView,
            text: model.text,
            parseResult: model.currentParseResult,
            diagnostics: model.diagnostics,
            theme: theme
        )

        // Update gutter.
        if let gutter = nsView.subviews.first(where: { $0 is GutterSideView }) as? GutterSideView {
            gutter.lineMap = DiagnosticLineMap(text: model.text, diagnostics: model.diagnostics)
            gutter.theme = theme
            gutter.needsDisplay = true
        }
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

        // Set up gutter overlay.
        let gutter = GutterOverlayView()
        gutter.autoresizingMask = [.flexibleHeight]
        textView.addSubview(gutter)
        context.coordinator.textViewUI = textView
        context.coordinator.gutterViewUI = gutter
        updateGutterFrame(textView: textView, gutter: gutter)

        // Long press for diagnostic info.
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(TextViewCoordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        textView.addGestureRecognizer(longPress)

        return textView
    }

    public func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        let theme = EditorTheme.resolved(for: colorScheme)

        textView.backgroundColor = UIColor(theme.background)
        textView.textColor = UIColor(theme.foreground)
        textView.tintColor = UIColor(theme.foreground)

        if !coordinator.isSyncing && textView.text != model.text {
            coordinator.isSyncing = true
            let sel = textView.selectedRange
            textView.text = model.text
            let maxLen = (textView.text as NSString).length
            let loc = min(sel.location, maxLen)
            textView.selectedRange = NSRange(location: loc,
                                             length: min(sel.length, maxLen - loc))
            coordinator.isSyncing = false
        }

        coordinator.applyDecorations(
            textView: textView,
            text: model.text,
            parseResult: model.currentParseResult,
            diagnostics: model.diagnostics,
            theme: theme
        )

        // Update gutter overlay.
        if let gutter = coordinator.gutterViewUI {
            gutter.lineMap = DiagnosticLineMap(text: model.text, diagnostics: model.diagnostics)
            gutter.theme = theme
            updateGutterFrame(textView: textView, gutter: gutter)
            gutter.setNeedsDisplay()
        }
    }

    public func makeCoordinator() -> TextViewCoordinator {
        TextViewCoordinator(model: model)
    }

    private func updateGutterFrame(textView: UITextView, gutter: GutterOverlayView) {
        let width = gutter.gutterWidth
        gutter.frame = CGRect(x: 0, y: 0, width: width, height: textView.contentSize.height)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: width, bottom: 8, right: 8)
    }
}
#endif

// MARK: - Shared Coordinator (non-generic for @objc delegate conformance)

@MainActor
public final class TextViewCoordinator: NSObject {
    let model: any ConfigTextEditing
    var isSyncing = false

    #if os(macOS)
    weak var textView: NSTextView?
    weak var gutterView: GutterRulerView?
    weak var gutterSideView: GutterSideView?
    private let popoverController = DiagnosticPopoverController()
    private let completionController = CompletionPopupController()
    private var lastHoverDiagnostics: [Diagnostic] = []
    #else
    weak var textViewUI: UITextView?
    weak var gutterViewUI: GutterOverlayView?
    #endif

    init(model: any ConfigTextEditing) {
        self.model = model
        super.init()
        #if os(macOS)
        popoverController.onApplyFixIt = { [weak self] fixIt in
            self?.applyFixIt(fixIt)
        }
        #endif
    }

    // MARK: - Public commands

    /// Format the document in place as a single undo operation.
    public func formatDocument() {
        let source = model.text
        let cursorKey = JSONFormatter.keyAtOffset(cursorByteOffset() ?? 0, in: source)
        let formatted = JSONFormatter.format(source)
        if formatted != source {
            replaceAllText(with: formatted)
            if let key = cursorKey, let offset = JSONFormatter.offsetOfKey(key, in: formatted) {
                selectByteOffset(offset)
            }
        }
    }

    /// Sort all object keys alphabetically as a single undo operation.
    public func sortDocumentKeys() {
        let source = model.text
        let cursorKey = JSONFormatter.keyAtOffset(cursorByteOffset() ?? 0, in: source)
        let sorted = JSONFormatter.sortKeys(source)
        if sorted != source {
            replaceAllText(with: sorted)
            if let key = cursorKey, let offset = JSONFormatter.offsetOfKey(key, in: sorted) {
                selectByteOffset(offset)
            }
        }
    }

    /// Apply a fix-it as a single undo operation.
    public func applyFixIt(_ fixIt: FixIt) {
        replaceByteRange(fixIt.range, with: fixIt.replacement)
    }

    /// Select a byte range in the text view (e.g. from a problems list click).
    public func selectRange(_ range: Range<Int>) {
        let table = OffsetTable(model.text)
        let utf16Range = table.utf16Range(forByteRange: range)
        let nsRange = NSRange(location: utf16Range.lowerBound, length: utf16Range.count)

        #if os(macOS)
        if let textView {
            textView.setSelectedRange(nsRange)
            textView.scrollRangeToVisible(nsRange)
        }
        #else
        if let textView = textViewUI {
            textView.selectedRange = nsRange
            textView.scrollRangeToVisible(nsRange)
        }
        #endif
    }

    // MARK: - Gutter click

    func handleGutterClick(line: Int) {
        let lineMap = DiagnosticLineMap(text: model.text, diagnostics: model.diagnostics)
        if let diag = lineMap.selectDiagnostic(forLine: line) {
            selectRange(diag.range)
        }
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
        if let tk2Layout = textView.textLayoutManager,
           let contentManager = tk2Layout.textContentManager {
            // TextKit 2 path
            applyDecorations(
                layoutManager: tk2Layout,
                contentManager: contentManager,
                text: text,
                parseResult: parseResult,
                diagnostics: diagnostics,
                theme: theme
            )
        } else if let tk1Layout = textView.layoutManager {
            // TextKit 1 fallback — use temporary attributes (non-destructive,
            // like rendering attributes but for NSLayoutManager).
            applyDecorationsTK1(
                layoutManager: tk1Layout,
                text: text,
                parseResult: parseResult,
                diagnostics: diagnostics,
                theme: theme
            )
        }
    }

    private func applyDecorationsTK1(
        layoutManager: NSLayoutManager,
        text: String,
        parseResult: ParseResult?,
        diagnostics: [Diagnostic],
        theme: EditorTheme
    ) {
        let offsetTable = OffsetTable(text)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        // Clear previous temporary attributes.
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)
        layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: fullRange)
        layoutManager.removeTemporaryAttribute(.underlineColor, forCharacterRange: fullRange)

        // Base foreground for all text.
        layoutManager.addTemporaryAttribute(
            .foregroundColor, value: NSColor(theme.foreground), forCharacterRange: fullRange)

        // Syntax highlighting from the parse tree.
        let spans = parseResult?.syntaxSpans() ?? []
        for span in spans {
            let utf16 = offsetTable.utf16Range(forByteRange: span.byteRange)
            let nsRange = NSRange(location: utf16.lowerBound, length: utf16.count)
            guard nsRange.location + nsRange.length <= fullRange.length else { continue }
            layoutManager.addTemporaryAttribute(
                .foregroundColor, value: NSColor(theme.color(for: span.role)),
                forCharacterRange: nsRange)
        }

        // Diagnostic decoration.
        for diagnostic in diagnostics {
            guard !diagnostic.range.isEmpty else { continue }
            let utf16 = offsetTable.utf16Range(forByteRange: diagnostic.range)
            let nsRange = NSRange(location: utf16.lowerBound, length: utf16.count)
            guard nsRange.location + nsRange.length <= fullRange.length else { continue }

            switch diagnostic.severity {
            case .error:
                layoutManager.addTemporaryAttribute(
                    .underlineStyle, value: NSUnderlineStyle.thick.rawValue,
                    forCharacterRange: nsRange)
                layoutManager.addTemporaryAttribute(
                    .underlineColor, value: NSColor(theme.errorUnderline),
                    forCharacterRange: nsRange)
            case .warning:
                layoutManager.addTemporaryAttribute(
                    .underlineStyle, value: NSUnderlineStyle.single.rawValue,
                    forCharacterRange: nsRange)
                layoutManager.addTemporaryAttribute(
                    .underlineColor, value: NSColor(theme.warningUnderline),
                    forCharacterRange: nsRange)
            case .inert:
                layoutManager.addTemporaryAttribute(
                    .foregroundColor, value: NSColor(theme.inertText),
                    forCharacterRange: nsRange)
            }
        }
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

        // Reset rendering attributes: set base foreground for all text, clear underlines.
        // Using addRenderingAttribute with the base color instead of removeRenderingAttribute
        // because on macOS 26 (TextKit 2), removing foreground color leaves text invisible.
        layoutManager.addRenderingAttribute(
            .foregroundColor,
            value: Self.platformColor(theme.foreground),
            for: docRange
        )
        layoutManager.removeRenderingAttribute(.underlineStyle, for: docRange)
        layoutManager.removeRenderingAttribute(.underlineColor, for: docRange)

        // Syntax highlighting from the parse tree (overrides the base foreground).
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

    static func textRange(
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

    // MARK: - Text replacement helpers

    private func replaceAllText(with newText: String) {
        isSyncing = true
        defer { isSyncing = false }

        #if os(macOS)
        if let textView {
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.shouldChangeText(in: fullRange, replacementString: newText)
            textView.replaceCharacters(in: fullRange, with: newText)
            textView.didChangeText()
            model.text = textView.string
        } else {
            model.text = newText
        }
        #else
        if let textView = textViewUI {
            let fullRange = NSRange(location: 0, length: (textView.text as NSString).length)
            textView.selectedRange = fullRange
            textView.replace(textView.selectedTextRange!, withText: newText)
            model.text = textView.text
        } else {
            model.text = newText
        }
        #endif
    }

    private func replaceByteRange(_ byteRange: Range<Int>, with replacement: String) {
        let table = OffsetTable(model.text)
        let utf16Range = table.utf16Range(forByteRange: byteRange)
        let nsRange = NSRange(location: utf16Range.lowerBound, length: utf16Range.count)

        isSyncing = true
        defer { isSyncing = false }

        #if os(macOS)
        if let textView {
            textView.shouldChangeText(in: nsRange, replacementString: replacement)
            textView.replaceCharacters(in: nsRange, with: replacement)
            textView.didChangeText()
            model.text = textView.string
        } else {
            model.text = FixItApplicator.apply(
                FixIt(range: byteRange, replacement: replacement, label: ""),
                to: model.text)
        }
        #else
        if let textView = textViewUI {
            textView.selectedRange = nsRange
            if let selectedRange = textView.selectedTextRange {
                textView.replace(selectedRange, withText: replacement)
            }
            model.text = textView.text
        } else {
            model.text = FixItApplicator.apply(
                FixIt(range: byteRange, replacement: replacement, label: ""),
                to: model.text)
        }
        #endif
    }

    private func cursorByteOffset() -> Int? {
        let utf16Offset: Int?
        #if os(macOS)
        utf16Offset = textView?.selectedRange().location
        #else
        utf16Offset = textViewUI?.selectedRange.location
        #endif

        guard let offset = utf16Offset else { return nil }
        let table = OffsetTable(model.text)
        return table.byteOffset(forUTF16Offset: offset)
    }

    private func selectByteOffset(_ byteOffset: Int) {
        let table = OffsetTable(model.text)
        let utf16 = table.utf16Offset(forByteOffset: byteOffset)
        let nsRange = NSRange(location: utf16, length: 0)

        #if os(macOS)
        textView?.setSelectedRange(nsRange)
        textView?.scrollRangeToVisible(nsRange)
        #else
        textViewUI?.selectedRange = nsRange
        textViewUI?.scrollRangeToVisible(nsRange)
        #endif
    }
}

// MARK: - Delegate conformance

#if os(macOS)
extension TextViewCoordinator: NSTextViewDelegate {
    public func textDidChange(_ notification: Notification) {
        guard !isSyncing, let textView = notification.object as? NSTextView else { return }
        model.text = textView.string
        updateCompletion(in: textView)
    }

    public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if completionController.isShowing {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                completionController.moveUp()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                completionController.moveDown()
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:))
                || commandSelector == #selector(NSResponder.insertTab(_:))
            {
                completionController.acceptCurrent()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                completionController.dismiss()
                return true
            }
        }
        return false
    }

    private func updateCompletion(in textView: NSTextView) {
        guard let parseResult = model.currentParseResult,
              let byteOffset = cursorByteOffset()
        else {
            completionController.dismiss()
            return
        }

        let result = CompletionEngine.completions(in: parseResult, at: byteOffset)
        if result.items.isEmpty {
            completionController.dismiss()
            return
        }

        // Position near the cursor.
        let utf16 = textView.selectedRange().location
        let glyphRange = NSRange(location: utf16, length: 0)
        let origin = textView.textContainerOrigin
        var rect: NSRect
        if let layoutManager = textView.layoutManager {
            rect = layoutManager.boundingRect(
                forGlyphRange: glyphRange, in: textView.textContainer!)
            rect.origin.x += origin.x
            rect.origin.y += origin.y
        } else {
            let insertionRect = textView.firstRect(forCharacterRange: glyphRange, actualRange: nil)
            rect = textView.convert(insertionRect, from: nil)
        }
        rect.size.width = max(rect.size.width, 1)
        rect.size.height = max(rect.size.height, 14)

        completionController.show(
            result: result, near: rect, in: textView
        ) { [weak self] item, range in
            self?.replaceByteRange(range, with: item.text)
        }
    }
}

// MARK: - Mouse tracking for diagnostic popovers

extension TextViewCoordinator {
    @objc(mouseEntered:) public func mouseEntered(with event: NSEvent) {
        // Tracking area entered — diagnostics shown on mouseMoved.
    }

    @objc(mouseMoved:) public func mouseMoved(with event: NSEvent) {
        guard let textView else {
            popoverController.dismiss()
            return
        }

        let point = textView.convert(event.locationInWindow, from: nil)
        let utf16Offset = textView.characterIndexForInsertion(at: point)
        guard utf16Offset >= 0, utf16Offset != NSNotFound else {
            popoverController.dismiss()
            return
        }

        let table = OffsetTable(model.text)
        let byteOffset = table.byteOffset(forUTF16Offset: utf16Offset)

        // Find overlapping diagnostics.
        let overlapping = model.diagnostics.filter { diag in
            diag.range.contains(byteOffset) ||
            (diag.range.isEmpty && diag.range.lowerBound == byteOffset)
        }

        if overlapping.isEmpty {
            popoverController.dismiss()
            lastHoverDiagnostics = []
        } else if overlapping != lastHoverDiagnostics {
            lastHoverDiagnostics = overlapping
            // Position the popover near the character.
            let glyphRange = NSRange(location: utf16Offset, length: max(1, 0))
            let textContainerOrigin = textView.textContainerOrigin
            if let layoutManager = textView.layoutManager {
                var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer!)
                rect.origin.x += textContainerOrigin.x
                rect.origin.y += textContainerOrigin.y
                if rect.width > 0 && rect.height > 0 {
                    popoverController.show(diagnostics: overlapping, relativeTo: rect, of: textView)
                }
            } else {
                // Fallback: use cursor position.
                let rect = NSRect(x: point.x, y: point.y, width: 1, height: 14)
                popoverController.show(diagnostics: overlapping, relativeTo: rect, of: textView)
            }
        }
    }

    @objc(mouseExited:) public func mouseExited(with event: NSEvent) {
        popoverController.dismiss()
        lastHoverDiagnostics = []
    }
}
#else
extension TextViewCoordinator: UITextViewDelegate {
    public func textViewDidChange(_ textView: UITextView) {
        guard !isSyncing else { return }
        model.text = textView.text
    }
}

// MARK: - Long press for diagnostic info (iOS)

extension TextViewCoordinator {
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let textView = textViewUI
        else { return }

        let point = gesture.location(in: textView)
        let closest = textView.closestPosition(to: point)
        guard let position = closest else { return }
        let utf16Offset = textView.offset(from: textView.beginningOfDocument, to: position)
        guard utf16Offset >= 0 else { return }

        let table = OffsetTable(model.text)
        let byteOffset = table.byteOffset(forUTF16Offset: utf16Offset)

        let overlapping = model.diagnostics.filter { diag in
            diag.range.contains(byteOffset) ||
            (diag.range.isEmpty && diag.range.lowerBound == byteOffset)
        }

        guard !overlapping.isEmpty else { return }

        // Show a brief tooltip-style label.
        let message = overlapping.map { diag in
            let prefix: String
            switch diag.severity {
            case .error: prefix = "Error"
            case .warning: prefix = "Warning"
            case .inert: prefix = "Unused"
            }
            return "\(prefix): \(diag.message)"
        }.joined(separator: "\n")

        showTooltip(message, at: point, in: textView)
    }

    private func showTooltip(_ message: String, at point: CGPoint, in view: UIView) {
        let label = UILabel()
        label.text = message
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.backgroundColor = UIColor.systemBackground
        label.textColor = UIColor.label
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.layer.borderColor = UIColor.separator.cgColor
        label.layer.borderWidth = 0.5
        label.textAlignment = .left

        let maxWidth = min(300, view.bounds.width - 32)
        let size = label.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        let padding: CGFloat = 8
        label.frame = CGRect(
            x: min(point.x, view.bounds.width - size.width - padding * 2),
            y: point.y - size.height - 8,
            width: size.width + padding * 2,
            height: size.height + padding
        )
        view.addSubview(label)

        UIView.animate(withDuration: 0.3, delay: 2.0, options: []) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }
    }
}
#endif
