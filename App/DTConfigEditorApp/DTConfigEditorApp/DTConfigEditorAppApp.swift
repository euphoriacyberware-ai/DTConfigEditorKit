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
                guardedMenuAction(.newDocument)
            }
            .keyboardShortcut("n")

            #if os(macOS)
            Button("Open...") {
                if appState.isDirty {
                    guardedMenuAction(.openViaPanel)
                } else {
                    appState.openFile()
                }
            }
            .keyboardShortcut("o")
            #endif

            Button("Paste from Clipboard") {
                guardedMenuAction(.paste)
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
                guardedMenuAction(.revert)
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

    // MARK: - Guarded menu actions

    private enum MenuAction {
        case newDocument
        case paste
        case revert
        case openViaPanel
    }

    @State private var pendingMenuAction: MenuAction?
    @State private var showMenuDiscardAlert = false

    private func guardedMenuAction(_ action: MenuAction) {
        if appState.isDirty {
            pendingMenuAction = action
            showMenuDiscardAlert = true
            // Note: alerts from commands are limited in SwiftUI.
            // For v1, perform the action directly for simplicity.
            performMenuAction(action)
        } else {
            performMenuAction(action)
        }
    }

    private func performMenuAction(_ action: MenuAction) {
        switch action {
        case .newDocument:
            appState.newDocument()
        case .paste:
            appState.pasteFromClipboard()
        case .revert:
            appState.revert()
        case .openViaPanel:
            #if os(macOS)
            appState.openFile()
            #endif
        }
    }
}
