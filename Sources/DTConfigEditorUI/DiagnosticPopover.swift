import SwiftUI
import DTConfigCore

/// SwiftUI content for a diagnostic popover, showing severity, message,
/// code, and fix-it buttons for each overlapping diagnostic.
struct DiagnosticPopoverContent: View {
    let diagnostics: [Diagnostic]
    var onApplyFixIt: ((FixIt) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diag in
                HStack(alignment: .top, spacing: 6) {
                    severityIcon(diag.severity)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(diag.severity == .inert ? "Not used by this model" : diag.message)
                            .font(.system(size: 12))
                        Text(diag.code)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        if !diag.fixIts.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(Array(diag.fixIts.enumerated()), id: \.offset) { _, fixIt in
                                    Button(fixIt.label) {
                                        onApplyFixIt?(fixIt)
                                    }
                                    .font(.system(size: 11))
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: 400, alignment: .leading)
    }

    @ViewBuilder
    private func severityIcon(_ severity: Severity) -> some View {
        switch severity {
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 14))
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 14))
        case .inert:
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
        }
    }
}

#if os(macOS)
import AppKit

/// Manages the macOS diagnostic popover shown on hover.
@MainActor
final class DiagnosticPopoverController {
    private var popover: NSPopover?
    private var currentDiagnostics: [Diagnostic] = []
    var onApplyFixIt: ((FixIt) -> Void)?

    func show(diagnostics: [Diagnostic], relativeTo rect: NSRect, of view: NSView) {
        guard !diagnostics.isEmpty else {
            dismiss()
            return
        }

        // If showing the same diagnostics, don't re-create.
        if diagnostics == currentDiagnostics, popover?.isShown == true {
            return
        }

        dismiss()
        currentDiagnostics = diagnostics

        let content = DiagnosticPopoverContent(diagnostics: diagnostics) { [weak self] fixIt in
            self?.dismiss()
            self?.onApplyFixIt?(fixIt)
        }
        let hostingController = NSHostingController(rootView: content)

        let pop = NSPopover()
        pop.contentViewController = hostingController
        pop.behavior = .semitransient
        pop.show(relativeTo: rect, of: view, preferredEdge: .maxY)
        self.popover = pop
    }

    func dismiss() {
        popover?.performClose(nil)
        popover = nil
        currentDiagnostics = []
    }
}
#endif
