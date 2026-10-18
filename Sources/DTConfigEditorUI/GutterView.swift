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
              let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(theme.gutterText),
        ]

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? textView.visibleRect
        let containerOrigin = textView.textContainerOrigin
        let numberWidth = gutterWidth - iconSize - gutterPadding * 3
        let documentStart = contentManager.documentRange.location
        let firstVisible = layoutManager.textLayoutFragment(
            for: CGPoint(x: 0, y: max(0, visibleRect.minY - containerOrigin.y)))
        var lineNumber: Int?

        // Each layout fragment is one paragraph (one source line), however it wraps.
        layoutManager.enumerateTextLayoutFragments(
            from: firstVisible?.rangeInElement.location ?? documentStart,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            let frame = fragment.layoutFragmentFrame
            let yInGutter = frame.minY + containerOrigin.y - visibleRect.minY
            if yInGutter > visibleRect.height { return false }

            let line = lineNumber ?? self.lineNumber(
                atUTF16Offset: contentManager.offset(from: documentStart, to: fragment.rangeInElement.location),
                in: textView.string)
            lineNumber = line + 1

            // Center on the fragment's first visual line.
            let lineHeight = fragment.textLineFragments.first?.typographicBounds.height ?? frame.height

            let numStr = "\(line)" as NSString
            let numSize = numStr.size(withAttributes: attrs)
            let numX = numberWidth - numSize.width + self.gutterPadding
            let numY = yInGutter + (lineHeight - numSize.height) / 2
            numStr.draw(at: NSPoint(x: numX, y: numY), withAttributes: attrs)

            if let map = self.lineMap, let severity = map.severity(forLine: line) {
                let iconX = numberWidth + self.gutterPadding * 2
                let iconY = yInGutter + (lineHeight - self.iconSize) / 2
                let iconRect = NSRect(x: iconX, y: iconY, width: self.iconSize, height: self.iconSize)
                self.drawSeverityIcon(severity, in: iconRect)
            }
            return true
        }
    }

    /// The 1-based line number containing a UTF-16 offset.
    private func lineNumber(atUTF16Offset offset: Int, in string: String) -> Int {
        let text = string as NSString
        var line = 1
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: min(max(0, offset), text.length)),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in
            line += 1
        }
        return line
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
              let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return }

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? textView.visibleRect
        let y = point.y + visibleRect.minY - textView.textContainerOrigin.y
        guard let fragment = layoutManager.textLayoutFragment(for: CGPoint(x: 0, y: max(0, y))) else { return }
        let offset = contentManager.offset(
            from: contentManager.documentRange.location, to: fragment.rangeInElement.location)
        onGutterClick?(lineNumber(atUTF16Offset: offset, in: textView.string))
    }

    @objc func scrollViewDidScroll(_ notification: Notification) {
        needsDisplay = true
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
