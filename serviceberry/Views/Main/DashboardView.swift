import SwiftUI

/// Main dashboard view showing connection status and controls
struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var isSending = false
    @State private var lastError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection status card
                    connectionStatusCard

                    // Stats card
                    statsCard

                    // Manual send button
                    manualSendSection

                    // Server info (if LAN mode)
                    if let server = appState.serverInfo {
                        serverInfoCard(server)
                    }
                }
                .padding()
            }
            .navigationTitle("Serviceberry")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                connectIfNeeded()
            }
        }
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: appState.transportManager.connectionState.iconName)
                    .font(.title)
                    .foregroundStyle(connectionColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Status")
                        .font(.headline)
                    Text(appState.transportManager.connectionState.displayText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Connection toggle
                Button(action: toggleConnection) {
                    Text(appState.transportManager.connectionState.isConnected ? "Disconnect" : "Connect")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }

            // Transport mode indicator
            HStack {
                Image(systemName: appState.transportMode?.icon ?? "questionmark")
                    .foregroundStyle(.secondary)
                Text(appState.transportMode?.displayName ?? "Not configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    private var connectionColor: Color {
        switch appState.transportManager.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .error:
            return .red
        case .disconnected:
            return .gray
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Activity")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                StatItem(
                    icon: "arrow.up.circle.fill",
                    title: "Submissions",
                    value: "\(appState.transportManager.submissionCount)"
                )

                if let lastTime = appState.transportManager.lastSubmissionTime {
                    StatItem(
                        icon: "clock.fill",
                        title: "Last Sent",
                        value: lastTime.formatted(date: .omitted, time: .shortened)
                    )
                } else {
                    StatItem(
                        icon: "clock.fill",
                        title: "Last Sent",
                        value: "Never"
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Manual Send Section

    private var manualSendSection: some View {
        VStack(spacing: 12) {
            Button(action: sendLocation) {
                HStack {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "location.fill")
                    }
                    Text("Send Location Now")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(appState.transportManager.connectionState.isConnected ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!appState.transportManager.connectionState.isConnected || isSending)

            if let error = lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("Your server will automatically request location updates when needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Server Info Card

    private func serverInfoCard(_ server: ServerInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Server")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Name", value: server.name)
                InfoRow(label: "Address", value: "\(server.host):\(server.port)")
                if !server.version.isEmpty && server.version != "unknown" {
                    InfoRow(label: "Version", value: server.version)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Actions

    private func connectIfNeeded() {
        guard !appState.transportManager.connectionState.isConnected else { return }

        Task {
            do {
                try await appState.connect()
            } catch {
                // Connection failed, will show in UI
            }
        }
    }

    private func toggleConnection() {
        if appState.transportManager.connectionState.isConnected {
            appState.disconnect()
        } else {
            Task {
                try? await appState.connect()
            }
        }
    }

    private func sendLocation() {
        isSending = true
        lastError = nil

        Task {
            do {
                try await appState.transportManager.sendCurrentLocation()
            } catch {
                lastError = error.localizedDescription
            }
            isSending = false
        }
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
}
