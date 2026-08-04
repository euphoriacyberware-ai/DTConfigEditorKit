import SwiftUI
import DTConfigCore

/// A problems list showing all diagnostics grouped by severity.
///
/// Errors and warnings are shown by default; inert diagnostics are hidden
/// unless the user toggles them on.
public struct ProblemsListView: View {
    private let diagnostics: [Diagnostic]
    private let lineIndex: LineIndex
    private let onSelect: (Diagnostic) -> Void
    private let onApplyFixIt: ((FixIt) -> Void)?

    @State private var showErrors = true
    @State private var showWarnings = true
    @State private var showInert = false

    public init(
        diagnostics: [Diagnostic],
        text: String,
        onSelect: @escaping (Diagnostic) -> Void,
        onApplyFixIt: ((FixIt) -> Void)? = nil
    ) {
        self.diagnostics = diagnostics
        self.lineIndex = LineIndex(text)
        self.onSelect = onSelect
        self.onApplyFixIt = onApplyFixIt
    }

    public var body: some View {
        VStack(spacing: 0) {
            filterBar
            List {
                if showErrors {
                    let errors = diagnostics.filter { $0.severity == .error }
                    if !errors.isEmpty {
                        Section("Errors (\(errors.count))") {
                            ForEach(Array(errors.enumerated()), id: \.offset) { _, diag in
                                diagnosticRow(diag)
                            }
                        }
                    }
                }
                if showWarnings {
                    let warnings = diagnostics.filter { $0.severity == .warning }
                    if !warnings.isEmpty {
                        Section("Warnings (\(warnings.count))") {
                            ForEach(Array(warnings.enumerated()), id: \.offset) { _, diag in
                                diagnosticRow(diag)
                            }
                        }
                    }
                }
                if showInert {
                    let inerts = diagnostics.filter { $0.severity == .inert }
                    if !inerts.isEmpty {
                        Section("Unused (\(inerts.count))") {
                            ForEach(Array(inerts.enumerated()), id: \.offset) { _, diag in
                                diagnosticRow(diag)
                            }
                        }
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            filterToggle("Errors", systemImage: "xmark.circle.fill", color: .red, isOn: $showErrors)
            filterToggle("Warnings", systemImage: "exclamationmark.triangle.fill", color: .orange, isOn: $showWarnings)
            filterToggle("Unused", systemImage: "minus.circle", color: .secondary, isOn: $showInert)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func filterToggle(_ label: String, systemImage: String, color: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(label, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(color)
        }
        .toggleStyle(.button)
        .buttonStyle(.borderless)
    }

    private func diagnosticRow(_ diag: Diagnostic) -> some View {
        Button {
            onSelect(diag)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                severityIcon(diag.severity)
                VStack(alignment: .leading, spacing: 2) {
                    Text(diag.message)
                        .font(.system(size: 12))
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        let pos = lineIndex.position(at: diag.range.lowerBound)
                        Text("\(pos.line):\(pos.column)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(diag.code)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    if !diag.fixIts.isEmpty, let applyFixIt = onApplyFixIt {
                        HStack(spacing: 4) {
                            ForEach(Array(diag.fixIts.enumerated()), id: \.offset) { _, fixIt in
                                Button(fixIt.label) {
                                    applyFixIt(fixIt)
                                }
                                .font(.system(size: 11))
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func severityIcon(_ severity: Severity) -> some View {
        switch severity {
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .inert:
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
        }
    }
}
