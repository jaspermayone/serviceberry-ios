import Foundation
import Combine

/// Connection state for transports
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var iconName: String {
        switch self {
        case .disconnected:
            return "circle"
        case .connecting:
            return "circle.dotted"
        case .connected:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }

    var iconColor: String {
        switch self {
        case .disconnected:
            return "secondary"
        case .connecting:
            return "orange"
        case .connected:
            return "green"
        case .error:
            return "red"
        }
    }
}

/// Protocol for transport implementations (BLE and LAN)
protocol TransportProtocol: AnyObject {
    /// Current connection state
    var connectionState: ConnectionState { get }

    /// Publisher for connection state changes
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { get }

    /// Called when the server requests a location update
    var onLocationRequest: (() async -> Void)? { get set }

    /// Connect to the server
    func connect() async throws

    /// Disconnect from the server
    func disconnect()

    /// Send location payload to the server
    func sendLocation(_ payload: LocationPayload) async throws
}

/// Errors that can occur during transport operations
enum TransportError: LocalizedError {
    case notConnected
    case connectionFailed(String)
    case sendFailed(String)
    case invalidResponse
    case certificateMismatch

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to server"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .sendFailed(let reason):
            return "Send failed: \(reason)"
        case .invalidResponse:
            return "Invalid response from server"
        case .certificateMismatch:
            return "Server certificate does not match expected fingerprint"
        }
    }
}
