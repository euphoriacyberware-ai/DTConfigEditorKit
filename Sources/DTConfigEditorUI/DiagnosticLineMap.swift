import DTConfigCore

/// Maps diagnostics to line numbers for gutter display and per-line queries.
public struct DiagnosticLineMap: Sendable {
    private let lineIndex: LineIndex
    private let lineDiagnostics: [[Diagnostic]]

    /// Build a map from diagnostics to lines.
    ///
    /// Each diagnostic is assigned to every line its byte range touches.
    public init(text: String, diagnostics: [Diagnostic]) {
        let idx = LineIndex(text)
        self.lineIndex = idx
        let count = idx.lineCount
        var buckets = [[Diagnostic]](repeating: [], count: count)

        for diag in diagnostics {
            let startLine = idx.position(at: diag.range.lowerBound).line
            let endLine: Int
            if diag.range.isEmpty {
                endLine = startLine
            } else {
                // upperBound is exclusive; back off by 1 to get the last included byte's line.
                endLine = idx.position(at: max(diag.range.lowerBound, diag.range.upperBound - 1)).line
            }
            for line in startLine...endLine {
                let i = line - 1  // 1-based → 0-based
                if i >= 0 && i < count {
                    buckets[i].append(diag)
                }
            }
        }

        self.lineDiagnostics = buckets
    }

    /// Number of lines in the source text.
    public var lineCount: Int { lineIndex.lineCount }

    /// The worst non-inert severity on this line, or nil if none.
    /// Severity ranking: error > warning. Inert is excluded.
    public func severity(forLine line: Int) -> Severity? {
        let diags = diagnostics(forLine: line)
        var worst: Severity? = nil
        for diag in diags {
            switch diag.severity {
            case .error:
                return .error
            case .warning:
                worst = .warning
            case .inert:
                continue
            }
        }
        return worst
    }

    /// All diagnostics touching this 1-based line number.
    public func diagnostics(forLine line: Int) -> [Diagnostic] {
        let i = line - 1
        guard i >= 0 && i < lineDiagnostics.count else { return [] }
        return lineDiagnostics[i]
    }

    /// The first error or warning diagnostic on this line, for gutter click.
    public func selectDiagnostic(forLine line: Int) -> Diagnostic? {
        let diags = diagnostics(forLine: line)
        // Prefer errors, then warnings.
        return diags.first(where: { $0.severity == .error })
            ?? diags.first(where: { $0.severity == .warning })
    }
}
