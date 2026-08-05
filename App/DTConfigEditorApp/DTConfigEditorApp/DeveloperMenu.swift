#if DEBUG
import DTConfigEditorKit
import DTConfigBridge
import DrawThingsClient
import SwiftUI

// MARK: - Notifications for triggering developer sheets

extension Notification.Name {
    static let showRoundTripInspector = Notification.Name("showRoundTripInspector")
    static let showParseTreeDump = Notification.Name("showParseTreeDump")
}

// MARK: - Fixture Loader

struct FixtureItem: Identifiable {
    let id: String
    let name: String
    let filename: String
}

private let fixtures: [FixtureItem] = [
    FixtureItem(id: "krea-full", name: "Krea 2.0 (full)", filename: "DT_krea2_robo.json"),
    FixtureItem(id: "krea-min", name: "Krea 2.0 (minimal)", filename: "DT_krea2_robo_min.json"),
    FixtureItem(id: "wan22", name: "Wan 2.2 i2v", filename: "DT_wan2.2_i2v.json"),
    FixtureItem(id: "control", name: "Control Example", filename: "DT_Control_Example.json"),
    FixtureItem(id: "future", name: "Future Key", filename: "DT_future_key.json"),
]

private var fixturesDirectory: URL {
    let sourceFile = URL(fileURLWithPath: #filePath)
    return sourceFile
        .deletingLastPathComponent()  // DTConfigEditorApp/
        .deletingLastPathComponent()  // DTConfigEditorApp/
        .deletingLastPathComponent()  // App/
        .appendingPathComponent("Tests/Fixtures")
}

func loadFixture(_ fixture: FixtureItem) -> String? {
    let url = fixturesDirectory.appendingPathComponent(fixture.filename)
    return try? String(contentsOf: url, encoding: .utf8)
}

// MARK: - Developer Menu Commands (macOS)

struct DeveloperCommands: Commands {
    @FocusedValue(\.appState) var appState

    var body: some Commands {
        CommandMenu("Developer") {
            Menu("Load Fixture") {
                ForEach(fixtures) { fixture in
                    Button(fixture.name) {
                        if let text = loadFixture(fixture) {
                            appState?.loadText(text)
                        }
                    }
                }
            }

            Divider()

            Button("Round-Trip Inspector") {
                NotificationCenter.default.post(name: .showRoundTripInspector, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.control, .option])

            Button("Parse Tree Dump") {
                NotificationCenter.default.post(name: .showParseTreeDump, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.control, .option])

            Divider()

            Button("Copy Diagnostics as JSON") {
                copyDiagnosticsJSON()
            }
            .keyboardShortcut("d", modifiers: [.control, .option])
        }
    }

    private func copyDiagnosticsJSON() {
        guard let appState else { return }
        let diags = appState.model.diagnostics
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(diags),
              let json = String(data: data, encoding: .utf8) else { return }
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        #endif
    }
}

// MARK: - Round-Trip Inspector

struct RoundTripInspectorView: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Round-Trip Inspector")
                .font(.headline)

            if let config = appState.model.configuration {
                let keys = appState.currentKeys()
                let reemitted = ConfigurationInterop.text(
                    from: config, style: .preserveShape(keys: keys),
                    unknownKeys: appState.model.unknownKeys)

                if reemitted == appState.model.text {
                    Label("Byte-identical", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                } else {
                    Label("Differs", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title3)

                    diffView(original: appState.model.text, reemitted: reemitted)
                }
            } else {
                Text("Document is invalid -- cannot round-trip.")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 300)
    }

    @ViewBuilder
    private func diffView(original: String, reemitted: String) -> some View {
        #if os(macOS)
        HSplitView {
            VStack(alignment: .leading) {
                Text("Current Document").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    Text(original)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            VStack(alignment: .leading) {
                Text("Re-emitted (.preserveShape)").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    Text(reemitted)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        #else
        VStack(alignment: .leading) {
            Text("Current Document").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                Text(original)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            Text("Re-emitted (.preserveShape)").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                Text(reemitted)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        #endif
    }
}

// MARK: - Parse Tree Dump

struct ParseTreeDumpView: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parse Tree")
                .font(.headline)

            if let result = appState.model.currentParseResult {
                ScrollView {
                    Text(dumpNode(result.root))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                Text("\(result.tokens.count) tokens, \(result.errors.count) parse errors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No parse result available.")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }

    private func dumpNode(_ node: CSTNode, indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var out = "\(prefix)\(node.kind) [\(node.byteRange.lowerBound)..<\(node.byteRange.upperBound)]"
        out += " tokens[\(node.tokenRange.lowerBound)..<\(node.tokenRange.upperBound)]"
        if !node.children.isEmpty {
            out += "\n"
            out += node.children.map { dumpNode($0, indent: indent + 1) }.joined(separator: "\n")
        }
        return out
    }
}

// MARK: - Developer Overlay (sheets triggered by notifications)

struct DeveloperOverlay: ViewModifier {
    let appState: AppState
    @State private var showRoundTrip = false
    @State private var showParseTree = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showRoundTrip) {
                RoundTripInspectorView(appState: appState)
            }
            .sheet(isPresented: $showParseTree) {
                ParseTreeDumpView(appState: appState)
            }
            .onReceive(NotificationCenter.default.publisher(for: .showRoundTripInspector)) { _ in
                showRoundTrip = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showParseTreeDump)) { _ in
                showParseTree = true
            }
    }
}

extension View {
    func developerOverlay(appState: AppState) -> some View {
        modifier(DeveloperOverlay(appState: appState))
    }
}
#endif
