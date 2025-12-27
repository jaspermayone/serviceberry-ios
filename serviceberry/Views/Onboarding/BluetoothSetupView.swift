import SwiftUI
import CoreBluetooth

/// Bluetooth device setup screen
struct BluetoothSetupView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: OnboardingViewModel
    @StateObject private var bleTransport = BLETransport()

    @State private var isScanning = false
    @State private var connectionError: String?
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Find Your Server")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Make sure your Serviceberry server is running and nearby.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            // Scanning indicator or device list
            if bleTransport.discoveredPeripherals.isEmpty {
                Spacer()

                if isScanning {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scanning for devices...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("No devices found")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Button("Start Scanning") {
                            startScanning()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Spacer()
            } else {
                // Device list
                List {
                    ForEach(bleTransport.discoveredPeripherals, id: \.identifier) { peripheral in
                        Button(action: {
                            selectPeripheral(peripheral)
                        }) {
                            HStack {
                                Image(systemName: "desktopcomputer")
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading) {
                                    Text(peripheral.name ?? "Unknown Device")
                                        .font(.headline)
                                    Text(peripheral.identifier.uuidString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if isConnecting && viewModel.selectedPeripheral?.id == peripheral.identifier {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isConnecting)
                    }
                }
                .listStyle(.insetGrouped)
            }

            // Error message
            if let error = connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Scan button (when devices are shown)
            if !bleTransport.discoveredPeripherals.isEmpty && !isConnecting {
                Button(isScanning ? "Stop Scanning" : "Scan Again") {
                    if isScanning {
                        stopScanning()
                    } else {
                        startScanning()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .navigationTitle("Bluetooth Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startScanning()
        }
        .onDisappear {
            stopScanning()
        }
    }

    private func startScanning() {
        isScanning = true
        connectionError = nil
        bleTransport.startScanning()

        // Auto-stop after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if isScanning {
                stopScanning()
            }
        }
    }

    private func stopScanning() {
        isScanning = false
        bleTransport.stopScanning()
    }

    private func selectPeripheral(_ peripheral: CBPeripheral) {
        viewModel.selectedPeripheral = CBPeripheralWrapper(
            id: peripheral.identifier,
            name: peripheral.name ?? "Unknown"
        )

        isConnecting = true
        connectionError = nil

        Task {
            do {
                try await bleTransport.connect(to: peripheral)
                // Connection successful, proceed to permissions
                viewModel.navigateTo(.permissions)
            } catch {
                connectionError = error.localizedDescription
            }
            isConnecting = false
        }
    }
}

#Preview {
    NavigationStack {
        BluetoothSetupView()
    }
    .environmentObject(AppState())
    .environmentObject(OnboardingViewModel())
}
