import DTConfigEditorKit
import DTConfigBridge
import SwiftUI

@main
struct DTConfigEditorAppApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
        .commands {
            fileCommands
            editCommands
            formatCommands
            viewCommands
            #if DEBUG
            DeveloperCommands()
            #endif
        }

        #if os(macOS)
        Settings {
            PreferencesView(appState: appState)
        }
        #endif
    }

    // MARK: - File Menu

    @CommandsBuilder
    private var fileCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") {
                appState.request(.newDocument)
            }
            .keyboardShortcut("n")

            #if os(macOS)
            Button("Open...") {
                appState.request(.open(nil))
            }
            .keyboardShortcut("o")
            #endif

            Button("Paste from Clipboard") {
                appState.request(.paste)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Divider()

            #if os(macOS)
            Button("Save") {
                appState.saveFile()
            }
            .keyboardShortcut("s")
            .disabled(!appState.isDirty && appState.documentURL != nil)

            Button("Save As...") {
                appState.saveAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            #endif

            Divider()

            Button("Revert to Saved") {
                appState.request(.revert)
            }
            .disabled(!appState.isDirty)
        }
    }

    // MARK: - Edit Menu

    @CommandsBuilder
    private var editCommands: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Copy Document") {
                appState.copyToClipboard()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("Copy As \(appState.emissionStyleChoice.rawValue)") {
                appState.copyAs()
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(!appState.model.isValid)
        }
    }

    // MARK: - Format Menu

    @CommandsBuilder
    private var formatCommands: some Commands {
        CommandMenu("Format") {
            Button("Format Document") {
                appState.formatDocument()
            }
            .keyboardShortcut("f", modifiers: [.control, .shift])

            Button("Sort Keys") {
                appState.sortDocumentKeys()
            }
            .keyboardShortcut("s", modifiers: [.control, .shift])
        }
    }

    // MARK: - View Menu

    @CommandsBuilder
    private var viewCommands: some Commands {
        CommandGroup(after: .toolbar) {
            Toggle("Show Problems", isOn: $appState.showProblemsList)
                .keyboardShortcut("m", modifiers: [.command, .shift])
        }
    }
}
