import DTConfigEditorKit
import DTConfigBridge
import SwiftUI
import UniformTypeIdentifiers

// MARK: - FocusedValue for menu commands

struct AppStateKey: FocusedValueKey {
    typealias Value = AppState
}

extension FocusedValues {
    var appState: AppState? {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @Bindable var appState: AppState
    @State private var showConnectionSheet = false
    @State private var showDiscardAlert = false
    @State private var pendingAction: PendingAction?

    enum PendingAction {
        case paste
        case revert
        case newDocument
        case openURL(URL)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorArea
            StatusBarView(appState: appState)
        }
        .focusedValue(\.appState, appState)
        .navigationTitle(appState.documentTitle)
        #if os(macOS)
        .navigationSubtitle(appState.emissionStyleChoice.rawValue)
        #endif
        .toolbar { toolbarContent }
        .alert("Unsaved Changes", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) { performPendingAction() }
            Button("Cancel", role: .cancel) { pendingAction = nil }
        } message: {
            Text("You have unsaved changes. Discard them?")
        }
        .sheet(isPresented: $showConnectionSheet) {
            ConnectionView(appState: appState)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
        .preferredColorScheme(resolvedColorScheme)
        #if DEBUG
        .developerOverlay(appState: appState)
        #endif
    }

    // MARK: - Editor Area

    @ViewBuilder
    private var editorArea: some View {
        #if os(macOS)
        HSplitView {
            ConfigTextView(model: appState.model)
                .frame(minWidth: 300)

            if appState.showProblemsList {
                ProblemsListView(
                    diagnostics: appState.filteredDiagnostics,
                    text: appState.model.text,
                    onSelect: { _ in },
                    onApplyFixIt: { fixIt in
                        appState.model.text = FixItApplicator.apply(fixIt, to: appState.model.text)
                    }
                )
                .frame(minWidth: 250, idealWidth: 320)
            }
        }
        #else
        VStack(spacing: 0) {
            ConfigTextView(model: appState.model)

            if appState.showProblemsList {
                Divider()
                ProblemsListView(
                    diagnostics: appState.filteredDiagnostics,
                    text: appState.model.text,
                    onSelect: { _ in },
                    onApplyFixIt: { fixIt in
                        appState.model.text = FixItApplicator.apply(fixIt, to: appState.model.text)
                    }
                )
                .frame(maxHeight: 250)
            }
        }
        #endif
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(macOS)
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                guardedAction(.paste)
            } label: {
                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
            }
            .help("Replace document with clipboard contents")

            Picker("Emission Style", selection: Binding(
                get: { appState.emissionStyleChoice },
                set: { appState.switchEmissionStyle(to: $0) }
            )) {
                ForEach(EmissionStyleChoice.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            .help("Re-emit config in the selected style")

            Button {
                appState.showProblemsList.toggle()
            } label: {
                Label("Problems", systemImage: appState.showProblemsList
                      ? "sidebar.trailing" : "sidebar.trailing")
            }
            .help("Toggle problems list")

            Button {
                showConnectionSheet = true
            } label: {
                Label("Connection", systemImage: connectionIcon)
            }
            .help("Draw Things server connection")
        }
        #else
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Paste from Clipboard", systemImage: "doc.on.clipboard") {
                    guardedAction(.paste)
                }
                Button("Copy Document", systemImage: "doc.on.doc") {
                    appState.copyToClipboard()
                }
                Divider()
                Button("Format", systemImage: "text.alignleft") {
                    appState.formatDocument()
                }
                Button("Sort Keys", systemImage: "arrow.up.arrow.down") {
                    appState.sortDocumentKeys()
                }
                Divider()
                Button("Toggle Problems", systemImage: "list.bullet") {
                    appState.showProblemsList.toggle()
                }
                Button("Connection", systemImage: connectionIcon) {
                    showConnectionSheet = true
                }
            } label: {
                Label("Actions", systemImage: "ellipsis.circle")
            }
        }
        #endif
    }

    // MARK: - Helpers

    private var connectionIcon: String {
        switch appState.connectionState {
        case .connected: return "bolt.fill"
        case .error: return "bolt.slash"
        default: return "bolt"
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch appState.preferredColorScheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    // MARK: - Discard confirmation

    private func guardedAction(_ action: PendingAction) {
        if appState.isDirty {
            pendingAction = action
            showDiscardAlert = true
        } else {
            perform(action)
        }
    }

    private func performPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        perform(action)
    }

    private func perform(_ action: PendingAction) {
        switch action {
        case .paste:
            appState.pasteFromClipboard()
        case .revert:
            appState.revert()
        case .newDocument:
            appState.newDocument()
        case .openURL(let url):
            appState.readAndLoad(url: url)
        }
    }

    // MARK: - Drag and drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                guardedAction(.openURL(url))
            }
        }
        return true
    }
}
