import DTConfigEditorKit
import DTConfigBridge
import DrawThingsClient
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

@Observable
final class AppState {

    // MARK: - Document

    var model: ConfigEditorModel
    var documentURL: URL?
    var originalText: String
    /// Keys present in the document when it was loaded/pasted, used by .preserveShape.
    var loadedKeys: Set<String> = []

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
    }

    // MARK: - Document operations

    func loadText(_ text: String, url: URL? = nil) {
        model.text = text
        originalText = text
        loadedKeys = keysIn(text)
        documentURL = url
        #if os(macOS)
        if let url { NSDocumentController.shared.noteNewRecentDocumentURL(url) }
        #endif
    }

    func revert() {
        model.text = originalText
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
        let empty = "{\n  \n}"
        model.text = empty
        originalText = empty
        loadedKeys = []
        documentURL = nil
    }

    private func keysIn(_ text: String) -> Set<String> {
        let result = Parser.parse(text)
        guard let json = result.value ?? result.valueRecovered,
              case .object(let pairs) = json else { return [] }
        return Set(pairs.map(\.key))
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

    func switchEmissionStyle(to choice: EmissionStyleChoice) {
        guard let config = model.configuration else {
            emissionStyleChoice = choice
            return
        }
        // Capture the current key set before re-emission if not already captured.
        // This preserves the original document shape even if the user pasted via
        // Cmd+V (bypassing loadText) or if a prior style switch reduced the keys.
        if loadedKeys.isEmpty {
            loadedKeys = currentKeys()
        }
        let style = emitStyle(for: choice)
        let newText = ConfigurationInterop.text(from: config, style: style, unknownKeys: model.unknownKeys)
        emissionStyleChoice = choice
        model.text = newText
        originalText = newText
    }

    func emitStyle(for choice: EmissionStyleChoice) -> EmitStyle {
        switch choice {
        case .full: return .full
        case .nonDefaultOnly: return .nonDefaultOnly
        case .preserveShape:
            // If loadedKeys wasn't set (e.g. user pasted via Cmd+V into the text
            // view rather than the toolbar button), capture from the current document.
            if loadedKeys.isEmpty {
                loadedKeys = currentKeys()
            }
            return .preserveShape(keys: loadedKeys)
        }
    }

    func currentKeys() -> Set<String> {
        guard let result = model.currentParseResult,
              let json = result.value ?? result.valueRecovered,
              case .object(let pairs) = json else { return [] }
        return Set(pairs.map(\.key))
    }

    // MARK: - Format / Sort

    func formatDocument() {
        let formatted = JSONFormatter.format(model.text)
        if formatted != model.text { model.text = formatted }
    }

    func sortDocumentKeys() {
        let sorted = JSONFormatter.sortKeys(model.text)
        if sorted != model.text { model.text = sorted }
    }

    // MARK: - Connection

    func connect() {
        connectionState = .connecting
        connectionError = nil
        do {
            service = try DrawThingsService(address: connectionAddress, useTLS: connectionUseTLS)
            connectionState = .connected
        } catch {
            connectionState = .error
            connectionError = error.localizedDescription
            service = nil
        }
    }

    func disconnect() {
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

    func saveFile() {
        if let url = documentURL {
            writeToURL(url)
        } else {
            saveAs()
        }
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = documentURL?.lastPathComponent ?? "config.json"
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.writeToURL(url)
        }
    }

    private func writeToURL(_ url: URL) {
        do {
            try model.text.write(to: url, atomically: true, encoding: .utf8)
            markSaved(url: url)
        } catch {
            // In a real app, show an alert
            print("Save failed: \(error)")
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
            print("Open failed: \(error)")
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

    var isRoundTripIdentical: Bool {
        guard let config = model.configuration else { return false }
        let keys = currentKeys()
        let reemitted = ConfigurationInterop.text(
            from: config, style: .preserveShape(keys: keys), unknownKeys: model.unknownKeys)
        return reemitted == model.text
    }

    var filteredDiagnostics: [Diagnostic] {
        if showInertDiagnostics {
            return model.diagnostics
        }
        return model.diagnostics.filter { $0.severity != .inert }
    }
}
