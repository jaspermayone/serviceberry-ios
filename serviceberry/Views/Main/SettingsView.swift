import SwiftUI
internal import CoreLocation

/// Settings view for app configuration
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Connection section
                Section("Connection") {
                    HStack {
                        Label("Mode", systemImage: appState.transportMode?.icon ?? "questionmark")
                        Spacer()
                        Text(appState.transportMode?.displayName ?? "Not set")
                            .foregroundStyle(.secondary)
                    }

                    if let server = appState.serverInfo {
                        HStack {
                            Label("Server", systemImage: "desktopcomputer")
                            Spacer()
                            Text(server.name)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Label("Address", systemImage: "network")
                            Spacer()
                            Text("\(server.host):\(server.port)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }

                // Status section
                Section("Status") {
                    HStack {
                        Label("Connection", systemImage: appState.transportManager.connectionState.iconName)
                        Spacer()
                        Text(appState.transportManager.connectionState.displayText)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Submissions", systemImage: "arrow.up.circle")
                        Spacer()
                        Text("\(appState.transportManager.submissionCount)")
                            .foregroundStyle(.secondary)
                    }
                }

                // Location section
                Section("Location") {
                    HStack {
                        Label("Authorization", systemImage: "location")
                        Spacer()
                        Text(authorizationText)
                            .foregroundStyle(.secondary)
                    }

                    if appState.locationService.authorizationStatus == .denied ||
                       appState.locationService.authorizationStatus == .restricted {
                        Button("Open Settings") {
                            openSettings()
                        }
                    }
                }

                // About section
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://beacondb.net")!) {
                        Label("About BeaconDB", systemImage: "globe")
                    }
                }

                // Reset section
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset Setup", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("This will disconnect and return to the setup wizard.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Reset Setup?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    resetSetup()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will disconnect from the server and return to the setup wizard.")
            }
        }
    }

    private var authorizationText: String {
        switch appState.locationService.authorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When In Use"
        @unknown default:
            return "Unknown"
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func resetSetup() {
        appState.reset()
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
