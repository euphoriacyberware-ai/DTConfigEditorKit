import DTConfigBridge
import DrawThingsClient
import SwiftUI

struct ConnectionView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Server") {
                TextField("Address", text: $appState.connectionAddress)
                    .textFieldStyle(.roundedBorder)
                    #if os(macOS)
                    .frame(minWidth: 250)
                    #endif

                Toggle("Use TLS", isOn: $appState.connectionUseTLS)

                SecureField("Shared Secret (optional)", text: $appState.connectionSecret)
                    .textFieldStyle(.roundedBorder)
                    .help("Not persisted. Passed to the server for authentication if required.")
            }

            Section("Status") {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(appState.connectionState.rawValue)
                    if let err = appState.connectionError {
                        Text("- \(err)")
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
            }

            Section {
                HStack {
                    if appState.connectionState == .connected {
                        Button("Disconnect") {
                            appState.disconnect()
                        }
                    } else {
                        Button("Connect") {
                            appState.connect()
                        }
                        .disabled(appState.connectionAddress.isEmpty)
                    }
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(minWidth: 350, minHeight: 200)
        .padding()
        #endif
    }

    private var statusColor: Color {
        switch appState.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .error: return .red
        }
    }
}
