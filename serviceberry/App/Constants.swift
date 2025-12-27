import Foundation
import CoreBluetooth

enum Constants {
    // MARK: - BLE
    static let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    static let characteristicUUID = CBUUID(string: "abcdef01-1234-5678-1234-56789abcdef0")
    static let peripheralName = "Serviceberry"

    // MARK: - mDNS
    static let bonjourServiceType = "_serviceberry._tcp"
    static let bonjourDomain = "local."  // trailing dot is standard DNS format

    // MARK: - Server
    static let serverPort: UInt16 = 8080
    static let submitPath = "/submit"
    static let requestPath = "/request"
    static let statusPath = "/status"

    // MARK: - Polling
    static let requestPollInterval: TimeInterval = 5.0

    // MARK: - UserDefaults Keys
    enum UserDefaultsKeys {
        static let isOnboarded = "isOnboarded"
        static let transportMode = "transportMode"
        static let serverInfo = "serverInfo"
    }
}
