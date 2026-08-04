import SwiftUI

struct PreferencesView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appState.preferredColorScheme) {
                    ForEach(ColorSchemePreference.allCases) { scheme in
                        Text(scheme.rawValue).tag(scheme)
                    }
                }
            }

            Section("Editor") {
                Picker("Default Emission Style", selection: $appState.defaultEmissionStyle) {
                    ForEach(EmissionStyleChoice.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .help("Emission style used when creating a new document from a struct")

                Toggle("Show inert diagnostics", isOn: $appState.showInertDiagnostics)
                    .help("Show fields that are valid but unused by the current model family")
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 400, height: 220)
        #endif
    }
}
