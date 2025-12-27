import SwiftUI
internal import CoreLocation

/// Permissions request screen
struct PermissionsRequestView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var locationStatus: CLAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            // Header
            VStack(spacing: 12) {
                Text("Location Permission")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Serviceberry needs access to your location to send coordinates to your server for geolocation database improvement.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Status indicator
            statusView

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                if locationStatus == .notDetermined {
                    Button(action: requestPermission) {
                        Text("Allow Location Access")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else if locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways {
                    Button(action: proceed) {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: openSettings) {
                        Text("Open Settings")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button(action: proceed) {
                        Text("Skip for Now")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            updateStatus()
        }
    }

    @ViewBuilder
    private var statusView: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusColor.opacity(0.1))
        )
    }

    private var statusIcon: String {
        switch locationStatus {
        case .notDetermined:
            return "questionmark.circle"
        case .authorizedWhenInUse, .authorizedAlways:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        @unknown default:
            return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch locationStatus {
        case .notDetermined:
            return .orange
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        @unknown default:
            return .gray
        }
    }

    private var statusText: String {
        switch locationStatus {
        case .notDetermined:
            return "Permission not yet requested"
        case .authorizedWhenInUse:
            return "Location access granted (when in use)"
        case .authorizedAlways:
            return "Location access granted (always)"
        case .denied:
            return "Location access denied"
        case .restricted:
            return "Location access restricted"
        @unknown default:
            return "Unknown status"
        }
    }

    private func updateStatus() {
        locationStatus = appState.locationService.authorizationStatus
    }

    private func requestPermission() {
        appState.locationService.requestAuthorization()

        // Monitor for changes
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            updateStatus()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func proceed() {
        viewModel.navigateTo(.completion)
    }
}

#Preview {
    NavigationStack {
        PermissionsRequestView()
    }
    .environmentObject(AppState())
    .environmentObject(OnboardingViewModel())
}
