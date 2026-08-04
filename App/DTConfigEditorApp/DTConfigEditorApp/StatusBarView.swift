import DTConfigEditorKit
import DTConfigBridge
import SwiftUI

struct StatusBarView: View {
    let appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Validity
            Group {
                if appState.model.isValid {
                    Label("Valid", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Invalid", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 8)

            divider

            // Diagnostic counts
            let counts = appState.diagnosticCounts
            HStack(spacing: 6) {
                if counts.errors > 0 {
                    Label("\(counts.errors)", systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                }
                if counts.warnings > 0 {
                    Label("\(counts.warnings)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                if counts.inert > 0 {
                    Label("\(counts.inert)", systemImage: "minus.circle")
                        .foregroundStyle(.secondary)
                }
                if counts.errors == 0 && counts.warnings == 0 && counts.inert == 0 {
                    Text("No issues")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)

            divider

            // Byte count and key count
            Text("\(appState.byteCount) bytes, \(appState.topLevelKeyCount) keys")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            divider

            // Model family
            if let family = appState.detectedModelFamily, let name = appState.modelName {
                let shortName = name.count > 30
                    ? String(name.prefix(27)) + "..."
                    : name
                Text("\(shortName) (\(family)\(appState.isVideoModel ? ", video" : ""))")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)

                divider
            }

            // Round-trip identity
            if appState.model.isValid {
                Group {
                    if appState.isRoundTripIdentical {
                        Label("RT", systemImage: "equal.circle.fill")
                            .foregroundStyle(.green)
                            .help("Round-trip identical: text -> struct -> text matches")
                    } else {
                        Label("RT", systemImage: "equal.circle")
                            .foregroundStyle(.orange)
                            .help("Round-trip differs: text -> struct -> text does not match")
                    }
                }
                .padding(.horizontal, 8)

                divider
            }

            // Connection state
            HStack(spacing: 4) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                Text(appState.connectionState.rawValue)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .font(.caption)
        .frame(height: 22)
        #if os(macOS)
        .background(.bar)
        #else
        .background(Color(.systemBackground))
        #endif
    }

    private var divider: some View {
        Divider()
            .frame(height: 14)
    }

    private var connectionColor: Color {
        switch appState.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .error: return .red
        }
    }
}
