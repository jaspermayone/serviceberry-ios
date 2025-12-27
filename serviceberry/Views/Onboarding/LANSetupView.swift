import SwiftUI

/// LAN/mDNS server discovery screen
struct LANSetupView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: OnboardingViewModel
    @StateObject private var discovery = MDNSDiscovery()

    @State private var selectedServer: ServerInfo?
    @State private var showManualEntry = false
    @State private var manualHost = ""
    @State private var manualFingerprint = ""
    @State private var showDebugInfo = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Find Your Server")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Searching for Serviceberry servers on your local network...")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            // Server list or searching indicator
            if discovery.discoveredServers.isEmpty {
                Spacer()

                if discovery.isSearching {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Searching...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("No servers found")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("Make sure your server is running and connected to the same network.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Search Again") {
                            discovery.startBrowsing()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Enter Manually") {
                            showManualEntry = true
                        }
                        .buttonStyle(.bordered)

                        Button(showDebugInfo ? "Hide Debug" : "Show Debug") {
                            showDebugInfo.toggle()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    }

                    if showDebugInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Debug Info")
                                .font(.caption.bold())
                            Text("Service type: \(Constants.bonjourServiceType)")
                                .font(.caption2)
                            Text("Domain: \(Constants.bonjourDomain)")
                                .font(.caption2)
                            Text("Browser state: \(discovery.debugState)")
                                .font(.caption2)
                            Text("Searching: \(discovery.isSearching ? "Yes" : "No")")
                                .font(.caption2)
                            Text("Servers found: \(discovery.discoveredServers.count)")
                                .font(.caption2)
                            Text("iOS: \(UIDevice.current.systemVersion)")
                                .font(.caption2)
                            if let error = discovery.lastError {
                                Text("Error: \(error.localizedDescription)")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }

                Spacer()
            } else {
                // Server list
                List {
                    ForEach(discovery.discoveredServers) { server in
                        ServerRowView(
                            server: server,
                            isSelected: selectedServer?.id == server.id,
                            onSelect: { selectedServer = server }
                        )
                    }

                    Section {
                        Button("Enter Manually") {
                            showManualEntry = true
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }

            // Continue button
            if selectedServer != nil {
                Button(action: {
                    viewModel.selectedServer = selectedServer
                    viewModel.navigateTo(.permissions)
                }) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle("Network Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            discovery.startBrowsing()
        }
        .onDisappear {
            discovery.stopBrowsing()
        }
        .sheet(isPresented: $showManualEntry) {
            ManualServerEntryView(
                host: $manualHost,
                fingerprint: $manualFingerprint,
                onSave: { host, fingerprint in
                    let server = ServerInfo(
                        name: "Manual Server",
                        host: host,
                        port: Constants.serverPort,
                        certFingerprint: fingerprint,
                        version: "unknown",
                        paths: [Constants.submitPath, Constants.statusPath, Constants.requestPath]
                    )
                    selectedServer = server
                    showManualEntry = false
                }
            )
        }
    }
}

/// Row view for a discovered server
struct ServerRowView: View {
    let server: ServerInfo
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var showFingerprint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onSelect) {
                HStack {
                    Image(systemName: "desktopcomputer")
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.name)
                            .font(.headline)
                        Text(server.host)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !server.version.isEmpty && server.version != "unknown" {
                            Text("v\(server.version)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .buttonStyle(.plain)

            // Show fingerprint when selected
            if isSelected && !server.certFingerprint.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: { showFingerprint.toggle() }) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(.green)
                            Text(showFingerprint ? "Hide Certificate" : "Verify Certificate")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }

                    if showFingerprint {
                        Text("Verify this matches your server:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(formatFingerprint(server.certFingerprint))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                            .textSelection(.enabled)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func formatFingerprint(_ fingerprint: String) -> String {
        // Format as XX:XX:XX:XX... for readability
        var formatted = ""
        for (index, char) in fingerprint.uppercased().enumerated() {
            if index > 0 && index % 2 == 0 {
                formatted += ":"
            }
            formatted.append(char)
        }
        return formatted
    }
}

/// Manual server entry sheet
struct ManualServerEntryView: View {
    @Binding var host: String
    @Binding var fingerprint: String
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Address") {
                    TextField("Hostname (e.g., myserver.local)", text: $host)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }

                Section {
                    TextField("Certificate Fingerprint (optional)", text: $fingerprint)
                        .autocapitalization(.none)
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("TLS Certificate")
                } footer: {
                    Text("Enter the SHA256 fingerprint shown by your server to verify secure connection. You can skip this if connecting on a trusted network.")
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(host, fingerprint)
                    }
                    .disabled(host.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LANSetupView()
    }
    .environmentObject(AppState())
    .environmentObject(OnboardingViewModel())
}
