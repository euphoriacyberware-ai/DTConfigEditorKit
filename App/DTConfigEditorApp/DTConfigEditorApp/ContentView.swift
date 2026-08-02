import SwiftUI
import DTConfigEditorKit

struct ContentView: View {
    @State private var config: DrawThingsConfiguration?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let _ = config {
                    JSONEditorView(config: configBinding)
                } else {
                    emptyState
                }
            }
            .navigationTitle("DT Config Editor")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("Paste Config", systemImage: "doc.on.clipboard")
                    }
                }

                if config != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            copyToClipboard()
                        } label: {
                            Label("Copy Config", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .alert("Error", isPresented: showingError, actions: {}) {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Configuration Loaded")
                .font(.headline)
            Text("Copy a Draw Things config JSON to your clipboard, then tap Paste.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Paste from Clipboard") {
                pasteFromClipboard()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Clipboard

    private func pasteFromClipboard() {
        #if os(iOS)
        guard let string = UIPasteboard.general.string else {
            errorMessage = "Clipboard is empty or does not contain text."
            return
        }
        #else
        guard let string = NSPasteboard.general.string(forType: .string) else {
            errorMessage = "Clipboard is empty or does not contain text."
            return
        }
        #endif

        guard let data = string.data(using: .utf8) else {
            errorMessage = "Could not read clipboard text as UTF-8."
            return
        }

        do {
            config = try DrawThingsConfiguration(jsonData: data)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to parse config: \(error.localizedDescription)"
        }
    }

    private func copyToClipboard() {
        guard let config else { return }
        do {
            let data = try config.jsonData()
            let string = String(data: data, encoding: .utf8) ?? ""
            #if os(iOS)
            UIPasteboard.general.string = string
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
            #endif
        } catch {
            errorMessage = "Failed to encode config: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private var configBinding: Binding<DrawThingsConfiguration> {
        Binding(
            get: { config! },
            set: { config = $0 }
        )
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
