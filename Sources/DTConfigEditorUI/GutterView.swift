import SwiftUI
import DTConfigCore

#if os(macOS)
import AppKit

// MARK: - GutterSideView (NSView-based, macOS 26 compatible)

/// A plain NSView that draws line numbers and diagnostic severity icons.
/// Sits alongside the NSScrollView rather than inside it as an NSRulerView,
/// which avoids an NSRulerView + NSTextView incompatibility on macOS 26
/// that causes the text view content to be invisible.
@MainActor
public final class GutterSideView: NSView {

    weak var textView: NSTextView?
    var lineMap: DiagnosticLineMap?
    var theme: EditorTheme = .light
    var onGutterClick: ((Int) -> Void)?

    private let iconSize: CGFloat = 12
    private let gutterPadding: CGFloat = 4

    var gutterWidth: CGFloat {
        let digitCount = max(3, String(lineMap?.lineCount ?? 1).count)
        let digitWidth = CGFloat(digitCount) * 8.0
        return digitWidth + iconSize + gutterPadding * 3
    }

    override public var isFlipped: Bool { true }

    override public func draw(_ dirtyRect: NSRect) {
        // Fill gutter background.
        NSColor(theme.gutterBackground).setFill()
        bounds.fill()

        // Draw separator line on the right edge.
        NSColor(theme.gutterSeparator).setStroke()
        let separatorX = bounds.maxX - 0.5
        let line = NSBezierPath()
        line.move(to: NSPoint(x: separatorX, y: dirtyRect.minY))
        line.line(to: NSPoint(x: separatorX, y: dirtyRect.maxY))
        line.lineWidth = 1
        line.stroke()

        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(theme.gutterText),
        ]

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let text = textView.string as NSString
        let numberWidth = gutterWidth - iconSize - gutterPadding * 3

        // Count lines before the visible range to get the starting line number.
        var lineNumber = 1
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: min(charRange.location, text.length)),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in
            lineNumber += 1
        }

        // Enumerate visible lines.
        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let yInGutter = lineRect.origin.y - visibleRect.origin.y

            // Draw line number.
            let numStr = "\(lineNumber)" as NSString
            let numSize = numStr.size(withAttributes: attrs)
            let numX = numberWidth - numSize.width + gutterPadding
            let numY = yInGutter + (lineRect.height - numSize.height) / 2
            numStr.draw(at: NSPoint(x: numX, y: numY), withAttributes: attrs)

            // Draw severity icon.
            if let map = lineMap, let severity = map.severity(forLine: lineNumber) {
                let iconX = numberWidth + gutterPadding * 2
                let iconY = yInGutter + (lineRect.height - iconSize) / 2
                let iconRect = NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
                drawSeverityIcon(severity, in: iconRect)
            }

            lineNumber += 1
            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }

    private func drawSeverityIcon(_ severity: Severity, in rect: NSRect) {
        let symbolName: String
        let color: NSColor
        switch severity {
        case .error:
            symbolName = "xmark.circle.fill"
            color = NSColor(theme.errorUnderline)
        case .warning:
            symbolName = "exclamationmark.triangle.fill"
            color = NSColor(theme.warningUnderline)
        case .inert:
            return
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: severity.rawValue) {
            let config = NSImage.SymbolConfiguration(pointSize: iconSize - 2, weight: .regular)
            let configured = image.withSymbolConfiguration(config) ?? image
            configured.isTemplate = true
            NSGraphicsContext.current?.saveGraphicsState()
            color.set()
            configured.draw(in: rect, from: .zero, operation: .sourceAtop, fraction: 1.0)
            NSGraphicsContext.current?.restoreGraphicsState()
        }
    }

    override public func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return }

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? textView.visibleRect
        let textPoint = NSPoint(x: 0, y: point.y + visibleRect.origin.y)
        let glyphIndex = layoutManager.glyphIndex(for: textPoint, in: textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

        let text = textView.string as NSString
        var clickedLine = 1
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: min(charIndex, text.length)),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in
            clickedLine += 1
        }
        onGutterClick?(clickedLine)
    }

    @objc func scrollViewDidScroll(_ notification: Notification) {
        needsDisplay = true
    }
}

// MARK: - GutterRulerView (legacy, kept for reference)

/// A ruler view that displays line numbers and diagnostic severity icons
/// in the gutter of an NSScrollView containing an NSTextView.
/// NOTE: NSRulerView causes invisible text on macOS 26. Use GutterSideView instead.
@MainActor
public final class GutterRulerView: NSRulerView {

    var lineMap: DiagnosticLineMap?
    var theme: EditorTheme = .light
    var onGutterClick: ((Int) -> Void)?

    private let iconSize: CGFloat = 12
    private let gutterPadding: CGFloat = 4

    override public var requiredThickness: CGFloat {
        let digitCount = max(3, String(lineMap?.lineCount ?? 1).count)
        let digitWidth = CGFloat(digitCount) * 8.0  // approximate monospaced digit width
        return digitWidth + iconSize + gutterPadding * 3
    }

    override public func draw(_ dirtyRect: NSRect) {
        // Fill gutter background.
        NSColor(theme.gutterBackground).setFill()
        dirtyRect.fill()

        // Draw separator line on the right edge.
        NSColor(theme.gutterSeparator).setStroke()
        let separatorX = bounds.maxX - 0.5
        let line = NSBezierPath()
        line.move(to: NSPoint(x: separatorX, y: dirtyRect.minY))
        line.line(to: NSPoint(x: separatorX, y: dirtyRect.maxY))
        line.lineWidth = 1
        line.stroke()

        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(theme.gutterText),
        ]

        let visibleRect = scrollView?.contentView.bounds ?? bounds
        var lineNumber = 1
        let numberWidth = requiredThickness - iconSize - gutterPadding * 3

        layoutManager.enumerateTextLayoutFragments(
            from: contentManager.documentRange.location,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            let fragmentFrame = fragment.layoutFragmentFrame
            // Convert fragment frame to ruler coordinates.
            let yInRuler = fragmentFrame.origin.y - visibleRect.origin.y

            // Skip fragments outside the dirty rect (with margin).
            if yInRuler + fragmentFrame.height < dirtyRect.minY - 20 {
                lineNumber += 1
                return true
            }
            if yInRuler > dirtyRect.maxY + 20 {
                return false
            }

            // Draw line number.
            let numStr = "\(lineNumber)" as NSString
            let numSize = numStr.size(withAttributes: attrs)
            let numX = numberWidth - numSize.width + gutterPadding
            let numY = yInRuler + (fragmentFrame.height - numSize.height) / 2
            numStr.draw(at: NSPoint(x: numX, y: numY), withAttributes: attrs)

            // Draw severity icon.
            if let map = lineMap, let severity = map.severity(forLine: lineNumber) {
                let iconX = numberWidth + gutterPadding * 2
                let iconY = yInRuler + (fragmentFrame.height - iconSize) / 2
                let iconRect = NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
                drawSeverityIcon(severity, in: iconRect)
            }

            lineNumber += 1
            return true
        }
    }

    private func drawSeverityIcon(_ severity: Severity, in rect: NSRect) {
        let symbolName: String
        let color: NSColor
        switch severity {
        case .error:
            symbolName = "xmark.circle.fill"
            color = NSColor(theme.errorUnderline)
        case .warning:
            symbolName = "exclamationmark.triangle.fill"
            color = NSColor(theme.warningUnderline)
        case .inert:
            return  // No icon for inert
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: severity.rawValue) {
            let config = NSImage.SymbolConfiguration(pointSize: iconSize - 2, weight: .regular)
            let configured = image.withSymbolConfiguration(config) ?? image
            configured.isTemplate = true
            NSGraphicsContext.current?.saveGraphicsState()
            color.set()
            configured.draw(in: rect, from: .zero, operation: .sourceAtop, fraction: 1.0)
            NSGraphicsContext.current?.restoreGraphicsState()
        }
    }

    override public func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let lineNumber = lineAtPoint(point)
        if lineNumber > 0 {
            onGutterClick?(lineNumber)
        }
    }

    private func lineAtPoint(_ point: NSPoint) -> Int {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return 0 }

        let visibleRect = scrollView?.contentView.bounds ?? bounds
        let textPoint = NSPoint(x: 0, y: point.y + visibleRect.origin.y)
        var lineNumber = 1

        layoutManager.enumerateTextLayoutFragments(
            from: contentManager.documentRange.location,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            let frame = fragment.layoutFragmentFrame
            if textPoint.y >= frame.minY && textPoint.y < frame.maxY {
                return false
            }
            lineNumber += 1
            return true
        }

        return lineNumber
    }
}

#else // iOS

import UIKit

/// An overlay view that draws line numbers and severity icons alongside
/// a UITextView. Added as a subview; position is corrected on scroll.
@MainActor
public final class GutterOverlayView: UIView {

    var lineMap: DiagnosticLineMap?
    var theme: EditorTheme = .light
    var onGutterClick: ((Int) -> Void)?

    private let iconSize: CGFloat = 12
    private let gutterPadding: CGFloat = 4

    public var gutterWidth: CGFloat {
        let digitCount = max(3, String(lineMap?.lineCount ?? 1).count)
        let digitWidth = CGFloat(digitCount) * 8.0
        return digitWidth + iconSize + gutterPadding * 3
    }

    override public func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Fill gutter background.
        context.setFillColor(UIColor(theme.gutterBackground).cgColor)
        context.fill(rect)

        // Draw separator.
        context.setStrokeColor(UIColor(theme.gutterSeparator).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: bounds.maxX - 0.5, y: rect.minY))
        context.addLine(to: CGPoint(x: bounds.maxX - 0.5, y: rect.maxY))
        context.strokePath()

        // Find the text view.
        guard let textView = superview as? UITextView,
              let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return }

        let font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(theme.gutterText),
        ]

        let numberWidth = gutterWidth - iconSize - gutterPadding * 3
        var lineNumber = 1

        layoutManager.enumerateTextLayoutFragments(
            from: contentManager.documentRange.location,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            let fragmentFrame = fragment.layoutFragmentFrame
            let yInGutter = fragmentFrame.origin.y

            if yInGutter + fragmentFrame.height < rect.minY - 20 {
                lineNumber += 1
                return true
            }
            if yInGutter > rect.maxY + 20 {
                return false
            }

            let numStr = "\(lineNumber)" as NSString
            let numSize = numStr.size(withAttributes: attrs)
            let numX = numberWidth - numSize.width + gutterPadding
            let numY = yInGutter + (fragmentFrame.height - numSize.height) / 2
            numStr.draw(at: CGPoint(x: numX, y: numY), withAttributes: attrs)

            if let map = lineMap, let severity = map.severity(forLine: lineNumber) {
                let iconX = numberWidth + gutterPadding * 2
                let iconY = yInGutter + (fragmentFrame.height - iconSize) / 2
                let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
                drawSeverityIcon(severity, in: iconRect, context: context)
            }

            lineNumber += 1
            return true
        }
    }

    private func drawSeverityIcon(_ severity: Severity, in rect: CGRect, context: CGContext) {
        let symbolName: String
        let color: UIColor
        switch severity {
        case .error:
            symbolName = "xmark.circle.fill"
            color = UIColor(theme.errorUnderline)
        case .warning:
            symbolName = "exclamationmark.triangle.fill"
            color = UIColor(theme.warningUnderline)
        case .inert:
            return
        }

        let config = UIImage.SymbolConfiguration(pointSize: iconSize - 2, weight: .regular)
        if let image = UIImage(systemName: symbolName, withConfiguration: config) {
            let tinted = image.withTintColor(color, renderingMode: .alwaysOriginal)
            tinted.draw(in: rect)
        }
    }
}

#endif
