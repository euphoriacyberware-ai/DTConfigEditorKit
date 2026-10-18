import DTConfigEditorKit
import DTConfigBridge
import SwiftUI
import UniformTypeIdentifiers

enum ConnectionState: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case connected = "Connected"
    case error = "Error"
}

enum ColorSchemePreference: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { rawValue }
}

enum EmissionStyleChoice: String, CaseIterable, Identifiable {
    case full = "Full"
    case nonDefaultOnly = "Non-Default Only"
    case preserveShape = "Preserve Shape"
    var id: String { rawValue }
}

/// An action that replaces the document, so it asks first when there are unsaved changes.
enum DocumentAction {
    case newDocument
    case paste
    case revert
    /// Open a file; nil shows the open panel.
    case open(URL?)
    case load(String)
}

@Observable
final class AppState {

    // MARK: - Document

    var model: ConfigEditorModel
    var documentURL: URL?
    var originalText: String
    /// Undoable edits through the text view.
    @ObservationIgnored let editor = ConfigEditorActions()

    /// The document's shape for .preserveShape: the keys it was loaded with, plus keys the
    /// user has since added and minus keys they removed. Re-emitting in another style
    /// doesn't change it.
    private(set) var shapeKeys: Set<String> = []
    /// Keys of the text last produced by a style switch, to tell its keys from the user's edits.
    @ObservationIgnored private var lastEmittedKeys: Set<String>?

    /// An action waiting for the user to save or discard unsaved changes.
    var pendingAction: DocumentAction?
    /// Saving first makes no sense before reverting to the saved text.
    var canSaveBeforePendingAction: Bool {
        if case .revert = pendingAction { return false }
        return true
    }
    /// An error to show the user.
    var alertMessage: String?

    var isDirty: Bool { model.text != originalText }

    var documentTitle: String {
        let name = documentURL?.lastPathComponent ?? "Untitled"
        return isDirty ? "\(name) - Edited" : name
    }

    // MARK: - Emission style

    var emissionStyleChoice: EmissionStyleChoice = .nonDefaultOnly

    // MARK: - Connection

    var connectionAddress: String {
        didSet { UserDefaults.standard.set(connectionAddress, forKey: "connectionAddress") }
    }
    var connectionUseTLS: Bool {
        didSet { UserDefaults.standard.set(connectionUseTLS, forKey: "connectionUseTLS") }
    }
    var connectionSecret: String = ""
    var connectionState: ConnectionState = .disconnected
    var connectionError: String?
    private(set) var service: DrawThingsService?

    // MARK: - Preferences

    var preferredColorScheme: ColorSchemePreference {
        didSet { UserDefaults.standard.set(preferredColorScheme.rawValue, forKey: "colorScheme") }
    }
    var defaultEmissionStyle: EmissionStyleChoice {
        didSet { UserDefaults.standard.set(defaultEmissionStyle.rawValue, forKey: "defaultEmissionStyle") }
    }
    var showInertDiagnostics: Bool {
        didSet { UserDefaults.standard.set(showInertDiagnostics, forKey: "showInertDiagnostics") }
    }

    // MARK: - UI state

    var showProblemsList: Bool = true

    // MARK: - Init

    init() {
        let empty = "{\n  \n}"
        let m = ConfigEditorModel(text: empty)
        self.model = m
        self.originalText = empty

        self.connectionAddress = UserDefaults.standard.string(forKey: "connectionAddress") ?? "localhost:7859"
        self.connectionUseTLS = UserDefaults.standard.bool(forKey: "connectionUseTLS")
        self.preferredColorScheme = ColorSchemePreference(
            rawValue: UserDefaults.standard.string(forKey: "colorScheme") ?? "") ?? .system
        self.defaultEmissionStyle = EmissionStyleChoice(
            rawValue: UserDefaults.standard.string(forKey: "defaultEmissionStyle") ?? "") ?? .nonDefaultOnly
        self.showInertDiagnostics = UserDefaults.standard.bool(forKey: "showInertDiagnostics")
        self.emissionStyleChoice = defaultEmissionStyle
    }

    // MARK: - Document operations

    /// Performs `action`, first asking to save or discard unsaved changes.
    func request(_ action: DocumentAction) {
        if isDirty {
            pendingAction = action
        } else {
            perform(action)
        }
    }

    /// Completes the pending action, saving first when asked to.
    func resolvePendingAction(save: Bool) {
        guard let action = pendingAction else { return }
        pendingAction = nil
        #if os(macOS)
        if save {
            saveFile { [weak self] in self?.perform(action) }
            return
        }
        #endif
        perform(action)
    }

    private func perform(_ action: DocumentAction) {
        switch action {
        case .newDocument:
            newDocument()
        case .paste:
            pasteFromClipboard()
        case .revert:
            revert()
        case .open(let url?):
            readAndLoad(url: url)
        case .open(nil):
            #if os(macOS)
            openFile()
            #endif
        case .load(let text):
            loadText(text)
        }
    }

    func loadText(_ text: String, url: URL? = nil) {
        model.text = text
        originalText = text
        shapeKeys = currentKeys()
        lastEmittedKeys = nil
        documentURL = url
        #if os(macOS)
        if let url { NSDocumentController.shared.noteNewRecentDocumentURL(url) }
        #endif
    }

    func revert() {
        if !editor.replaceText(with: originalText) { model.text = originalText }
    }

    func markSaved(url: URL? = nil) {
        originalText = model.text
        if let url {
            documentURL = url
            #if os(macOS)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            #endif
        }
    }

    func newDocument() {
        loadText("{\n  \n}")
    }

    // MARK: - Clipboard

    func pasteFromClipboard() {
        #if os(macOS)
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        #else
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        #endif
        loadText(text)
    }

    func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.text, forType: .string)
        #else
        UIPasteboard.general.string = model.text
        #endif
    }

    func copyAs() {
        guard let config = model.configuration else { return }
        let style = emitStyle(for: emissionStyleChoice)
        let text = ConfigurationInterop.text(from: config, style: style, unknownKeys: model.unknownKeys)
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    // MARK: - Emission style

    /// Re-emits the document in `choice`'s style as one undoable edit. The document stays
    /// edited until saved.
    func switchEmissionStyle(to choice: EmissionStyleChoice) {
        emissionStyleChoice = choice
        guard let config = model.configuration else { return }
        updateShapeKeys()
        let newText = ConfigurationInterop.text(
            from: config, style: emitStyle(for: choice), unknownKeys: model.unknownKeys)
        if !editor.replaceText(with: newText) { model.text = newText }
        lastEmittedKeys = currentKeys()
    }

    func emitStyle(for choice: EmissionStyleChoice) -> EmitStyle {
        switch choice {
        case .full: return .full
        case .nonDefaultOnly: return .nonDefaultOnly
        case .preserveShape:
            updateShapeKeys()
            return .preserveShape(keys: shapeKeys)
        }
    }

    /// Folds the user's edits since the last style switch into ``shapeKeys``.
    private func updateShapeKeys() {
        let current = currentKeys()
        guard let emitted = lastEmittedKeys else {
            shapeKeys = current
            return
        }
        shapeKeys = shapeKeys.union(current.subtracting(emitted)).subtracting(emitted.subtracting(current))
    }

    func currentKeys() -> Set<String> {
        guard let result = model.currentParseResult,
              let json = result.value ?? result.valueRecovered,
              case .object(let pairs) = json else { return [] }
        return Set(pairs.map(\.key))
    }

    // MARK: - Format / Sort

    func formatDocument() {
        guard !editor.formatDocument() else { return }
        let formatted = JSONFormatter.format(model.text)
        if formatted != model.text { model.text = formatted }
    }

    func sortDocumentKeys() {
        guard !editor.sortDocumentKeys() else { return }
        let sorted = JSONFormatter.sortKeys(model.text)
        if sorted != model.text { model.text = sorted }
    }

    func applyFixIt(_ fixIt: FixIt) {
        guard !editor.applyFixIt(fixIt) else { return }
        model.text = FixItApplicator.apply(fixIt, to: model.text)
    }

    func reveal(_ diagnostic: Diagnostic) {
        editor.select(diagnostic.range)
    }

    // MARK: - Connection

    func connect() {
        connectionState = .connecting
        connectionError = nil
        do {
            let options = ConnectionOptions(
                security: connectionUseTLS ? .tls() : .plaintext,
                sharedSecret: connectionSecret.isEmpty ? nil : connectionSecret)
            service = try DrawThingsService(address: connectionAddress, options: options)
            connectionState = .connected
        } catch {
            connectionState = .error
            connectionError = error.localizedDescription
            service = nil
        }
    }

    func disconnect() {
        if let service {
            Task { await service.shutdown() }
        }
        service = nil
        connectionState = .disconnected
        connectionError = nil
    }

    // MARK: - File I/O

    #if os(macOS)
    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.readAndLoad(url: url)
        }
    }

    /// Saves, asking for a location if the document has none; `completion` runs only on success.
    func saveFile(completion: (() -> Void)? = nil) {
        if let url = documentURL {
            if writeToURL(url) { completion?() }
        } else {
            saveAs(completion: completion)
        }
    }

    func saveAs(completion: (() -> Void)? = nil) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = documentURL?.lastPathComponent ?? "config.json"
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            if self.writeToURL(url) { completion?() }
        }
    }

    private func writeToURL(_ url: URL) -> Bool {
        do {
            try model.text.write(to: url, atomically: true, encoding: .utf8)
            markSaved(url: url)
            return true
        } catch {
            alertMessage = "Couldn't save \(url.lastPathComponent): \(error.localizedDescription)"
            return false
        }
    }
    #endif

    func readAndLoad(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            loadText(text, url: url)
        } catch {
            alertMessage = "Couldn't open \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    // MARK: - Status bar computed properties

    var modelName: String? {
        model.configuration?.model
    }

    var detectedModelFamily: String? {
        guard let name = modelName else { return nil }
        return "\(ModelFamilyDetector.detect(from: name))"
    }

    var isVideoModel: Bool {
        guard let name = modelName else { return false }
        return ModelFamilyDetector.detect(from: name).nativeFrameRate != nil
    }

    var byteCount: Int { model.text.utf8.count }

    var topLevelKeyCount: Int {
        guard let result = model.currentParseResult,
              let json = result.value ?? result.valueRecovered,
              case .object(let pairs) = json else { return 0 }
        return pairs.count
    }

    var diagnosticCounts: (errors: Int, warnings: Int, inert: Int) {
        var e = 0, w = 0, i = 0
        for d in model.diagnostics {
            switch d.severity {
            case .error: e += 1
            case .warning: w += 1
            case .inert: i += 1
            }
        }
        return (e, w, i)
    }

    /// Whether re-emitting the document in its own shape reproduces it exactly. Cached per
    /// text, since the status bar asks on every render.
    var isRoundTripIdentical: Bool {
        let text = model.text
        if let cached = roundTripCache, cached.text == text { return cached.identical }
        var identical = false
        if let config = model.configuration {
            identical = ConfigurationInterop.text(
                from: config, style: .preserveShape(keys: currentKeys()),
                unknownKeys: model.unknownKeys) == text
        }
        roundTripCache = (text, identical)
        return identical
    }
    @ObservationIgnored private var roundTripCache: (text: String, identical: Bool)?
}
