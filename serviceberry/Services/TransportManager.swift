import Foundation
import Combine

/// Manages the active transport and coordinates location requests
@MainActor
class TransportManager: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastSubmissionTime: Date?
    @Published var submissionCount: Int = 0

    private var transport: TransportProtocol?
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()

    var mode: TransportMode?
    var serverInfo: ServerInfo?

    init(locationService: LocationService) {
        self.locationService = locationService
    }

    /// Configure transport based on mode
    func configure(mode: TransportMode, serverInfo: ServerInfo? = nil) {
        disconnect()

        self.mode = mode
        self.serverInfo = serverInfo

        LogManager.shared.info("Configuring transport: \(mode.displayName)", source: "Transport")

        switch mode {
        case .bluetooth:
            let ble = BLETransport()
            setupTransport(ble)
            transport = ble

        case .lan:
            guard let info = serverInfo else {
                LogManager.shared.error("No server info provided", source: "Transport")
                connectionState = .error("No server info provided")
                return
            }
            LogManager.shared.debug("Server: \(info.host):\(info.port)", source: "Transport")
            let lan = LANTransport(serverInfo: info)
            setupTransport(lan)
            transport = lan
        }
    }

    private func setupTransport(_ transport: TransportProtocol) {
        transport.onLocationRequest = { [weak self] in
            await self?.handleLocationRequest()
        }

        transport.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)
    }

    /// Connect to the server using current transport
    func connect() async throws {
        guard let transport = transport else {
            throw TransportError.notConnected
        }
        try await transport.connect()
    }

    /// Disconnect from the server
    func disconnect() {
        transport?.disconnect()
        transport = nil
        cancellables.removeAll()
        connectionState = .disconnected
    }

    /// Handle incoming location request from server
    private func handleLocationRequest() async {
        LogManager.shared.info("Location request received from server", source: "Transport")
        do {
            let position = try await locationService.requestLocation()
            LogManager.shared.debug("Got position: \(position.latitude), \(position.longitude)", source: "Transport")
            let payload = LocationPayload(position: position)
            try await sendLocation(payload)
        } catch {
            LogManager.shared.error("Failed to handle location request: \(error.localizedDescription)", source: "Transport")
        }
    }

    /// Manually send current location
    func sendCurrentLocation() async throws {
        let position = try await locationService.requestLocation()
        let payload = LocationPayload(position: position)
        try await sendLocation(payload)
    }

    /// Send location payload
    private func sendLocation(_ payload: LocationPayload) async throws {
        guard let transport = transport else {
            throw TransportError.notConnected
        }

        try await transport.sendLocation(payload)
        lastSubmissionTime = Date()
        submissionCount += 1
        LogManager.shared.info("Location sent successfully (#\(submissionCount))", source: "Transport")
    }

    /// Get BLE transport for peripheral selection (only valid if mode is bluetooth)
    var bleTransport: BLETransport? {
        transport as? BLETransport
    }
}
