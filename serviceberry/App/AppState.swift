import Foundation
import Combine

/// Global application state
@MainActor
class AppState: ObservableObject {
    @Published var isOnboarded: Bool {
        didSet {
            UserDefaults.standard.set(isOnboarded, forKey: Constants.UserDefaultsKeys.isOnboarded)
        }
    }

    @Published var transportMode: TransportMode? {
        didSet {
            if let mode = transportMode {
                UserDefaults.standard.set(mode.rawValue, forKey: Constants.UserDefaultsKeys.transportMode)
            } else {
                UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.transportMode)
            }
        }
    }

    @Published var serverInfo: ServerInfo? {
        didSet {
            if let info = serverInfo,
               let data = try? JSONEncoder().encode(info) {
                UserDefaults.standard.set(data, forKey: Constants.UserDefaultsKeys.serverInfo)
            } else {
                UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.serverInfo)
            }
        }
    }

    let locationService: LocationService
    let transportManager: TransportManager

    init() {
        // Load persisted state
        self.isOnboarded = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.isOnboarded)

        if let modeString = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.transportMode) {
            self.transportMode = TransportMode(rawValue: modeString)
        } else {
            self.transportMode = nil
        }

        if let data = UserDefaults.standard.data(forKey: Constants.UserDefaultsKeys.serverInfo),
           let info = try? JSONDecoder().decode(ServerInfo.self, from: data) {
            self.serverInfo = info
        } else {
            self.serverInfo = nil
        }

        // Initialize services
        self.locationService = LocationService()
        self.transportManager = TransportManager(locationService: locationService)

        // Configure transport if already onboarded
        if isOnboarded, let mode = transportMode {
            transportManager.configure(mode: mode, serverInfo: serverInfo)
        }
    }

    /// Complete onboarding with selected mode and server info
    func completeOnboarding(mode: TransportMode, serverInfo: ServerInfo?) {
        self.transportMode = mode
        self.serverInfo = serverInfo
        self.isOnboarded = true

        transportManager.configure(mode: mode, serverInfo: serverInfo)
    }

    /// Reset to initial state (for re-running onboarding)
    func reset() {
        transportManager.disconnect()
        isOnboarded = false
        transportMode = nil
        serverInfo = nil
    }

    /// Connect to the server
    func connect() async throws {
        try await transportManager.connect()
    }

    /// Disconnect from the server
    func disconnect() {
        transportManager.disconnect()
    }
}
