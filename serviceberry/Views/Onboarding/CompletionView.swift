import SwiftUI

/// Setup completion screen
struct CompletionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var isConnecting = false
    @State private var connectionError: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            // Header
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Serviceberry is configured and ready to go.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Configuration summary
            VStack(spacing: 16) {
                SummaryRow(
                    icon: viewModel.selectedMode?.icon ?? "questionmark",
                    title: "Connection",
                    value: viewModel.selectedMode?.displayName ?? "Not set"
                )

                if let server = viewModel.selectedServer {
                    SummaryRow(
                        icon: "desktopcomputer",
                        title: "Server",
                        value: "\(server.name) (\(server.host))"
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal)

            // Error message
            if let error = connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()

            // Complete button
            Button(action: completeSetup) {
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                } else {
                    Text("Start Using Serviceberry")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .disabled(isConnecting)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Complete")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func completeSetup() {
        guard let mode = viewModel.selectedMode else { return }

        isConnecting = true
        connectionError = nil

        // Save configuration and complete onboarding
        appState.completeOnboarding(mode: mode, serverInfo: viewModel.selectedServer)

        // Try to connect
        Task {
            do {
                try await appState.connect()
            } catch {
                connectionError = "Connected but couldn't verify: \(error.localizedDescription)"
            }
            isConnecting = false
        }
    }
}

/// Summary row component
struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 30)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        CompletionView()
    }
    .environmentObject(AppState())
    .environmentObject({
        let vm = OnboardingViewModel()
        vm.selectedMode = .lan
        vm.selectedServer = ServerInfo(
            name: "Home Server",
            host: "192.168.1.100",
            port: 8080,
            certFingerprint: "abc123",
            version: "0.1.0",
            paths: []
        )
        return vm
    }())
}
