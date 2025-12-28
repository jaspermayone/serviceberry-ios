import Foundation
import CoreBluetooth
import Combine

/// BLE Central transport for communicating with Serviceberry server
class BLETransport: NSObject, ObservableObject, TransportProtocol {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?

    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var writeContinuation: CheckedContinuation<Void, Error>?

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published var discoveredPeripherals: [CBPeripheral] = []

    var onLocationRequest: (() async -> Void)?

    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "serviceberry-central"]
        )
    }

    /// Start scanning for Serviceberry peripherals
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredPeripherals = []
        LogManager.shared.info("Scanning for BLE peripherals", source: "BLE")
        centralManager.scanForPeripherals(
            withServices: [Constants.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    /// Stop scanning
    func stopScanning() {
        centralManager.stopScan()
    }

    /// Connect to a specific peripheral
    func connect(to peripheral: CBPeripheral) async throws {
        self.peripheral = peripheral
        try await connect()
    }

    func connect() async throws {
        guard let peripheral = peripheral else {
            throw TransportError.connectionFailed("No peripheral selected")
        }

        updateState(.connecting)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectionContinuation = continuation
            self.centralManager.connect(peripheral, options: nil)
        }
    }

    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        characteristic = nil
        updateState(.disconnected)
    }

    func sendLocation(_ payload: LocationPayload) async throws {
        guard let peripheral = peripheral,
              let characteristic = characteristic else {
            throw TransportError.notConnected
        }

        let encoder = JSONEncoder()
        var data = try encoder.encode(payload)
        // Append newline for server parsing
        data.append(0x0A)

        // Get max write length
        let maxLength = peripheral.maximumWriteValueLength(for: .withResponse)

        // Chunk if necessary
        var offset = 0
        while offset < data.count {
            let chunkSize = min(maxLength, data.count - offset)
            let chunk = data.subdata(in: offset..<offset + chunkSize)

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.writeContinuation = continuation
                peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
            }

            offset += chunkSize
        }
    }

    private func updateState(_ state: ConnectionState) {
        connectionState = state
        connectionStateSubject.send(state)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLETransport: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Ready to scan
            break
        case .poweredOff:
            updateState(.error("Bluetooth is turned off"))
        case .unauthorized:
            updateState(.error("Bluetooth access not authorized"))
        case .unsupported:
            updateState(.error("Bluetooth not supported"))
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            LogManager.shared.debug("Discovered: \(peripheral.name ?? "Unknown") (RSSI: \(RSSI))", source: "BLE")
            discoveredPeripherals.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        LogManager.shared.info("Connected to \(peripheral.name ?? "Unknown")", source: "BLE")
        peripheral.delegate = self
        peripheral.discoverServices([Constants.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        LogManager.shared.error("Connection failed: \(error?.localizedDescription ?? "Unknown")", source: "BLE")
        updateState(.error(error?.localizedDescription ?? "Connection failed"))
        connectionContinuation?.resume(throwing: TransportError.connectionFailed(error?.localizedDescription ?? "Unknown error"))
        connectionContinuation = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        LogManager.shared.warning("Disconnected from peripheral", source: "BLE")
        updateState(.disconnected)
        characteristic = nil
    }

    // State restoration
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let restoredPeripheral = peripherals.first {
            self.peripheral = restoredPeripheral
            restoredPeripheral.delegate = self
            if restoredPeripheral.state == .connected {
                restoredPeripheral.discoverServices([Constants.serviceUUID])
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLETransport: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            updateState(.error(error!.localizedDescription))
            connectionContinuation?.resume(throwing: TransportError.connectionFailed(error!.localizedDescription))
            connectionContinuation = nil
            return
        }

        if let service = peripheral.services?.first(where: { $0.uuid == Constants.serviceUUID }) {
            peripheral.discoverCharacteristics([Constants.characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            updateState(.error(error!.localizedDescription))
            connectionContinuation?.resume(throwing: TransportError.connectionFailed(error!.localizedDescription))
            connectionContinuation = nil
            return
        }

        if let char = service.characteristics?.first(where: { $0.uuid == Constants.characteristicUUID }) {
            self.characteristic = char
            // Subscribe to notifications
            peripheral.setNotifyValue(true, for: char)
            updateState(.connected)
            connectionContinuation?.resume()
            connectionContinuation = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let value = characteristic.value else { return }

        // Check if this is a location request from the server
        if let message = String(data: value, encoding: .utf8) {
            if message.lowercased().contains("request") || message == "GPS?" {
                Task {
                    await onLocationRequest?()
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            writeContinuation?.resume(throwing: TransportError.sendFailed(error.localizedDescription))
        } else {
            writeContinuation?.resume()
        }
        writeContinuation = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            LogManager.shared.error("Failed to subscribe to notifications: \(error.localizedDescription)", source: "BLE")
        } else {
            LogManager.shared.debug("Subscribed to notifications", source: "BLE")
        }
    }
}
