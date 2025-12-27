import Foundation

/// Transport method for communicating with the server
enum TransportMode: String, Codable {
    case bluetooth
    case lan

    var displayName: String {
        switch self {
        case .bluetooth:
            return "Bluetooth"
        case .lan:
            return "Local Network"
        }
    }

    var icon: String {
        switch self {
        case .bluetooth:
            return "antenna.radiowaves.left.and.right"
        case .lan:
            return "wifi"
        }
    }

    var description: String {
        switch self {
        case .bluetooth:
            return "Connect directly via Bluetooth Low Energy. Best for when your phone is near the server."
        case .lan:
            return "Connect over your local WiFi network. Discovers the server automatically via mDNS."
        }
    }
}
