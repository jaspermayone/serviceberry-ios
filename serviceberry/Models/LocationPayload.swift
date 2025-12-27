import Foundation

/// Payload sent to the server containing position and optional cell tower data
struct LocationPayload: Codable {
    let position: Position
    let cell_towers: [CellTower]?

    init(position: Position, cellTowers: [CellTower]? = nil) {
        self.position = position
        self.cell_towers = cellTowers
    }
}

/// Radio type for cell towers
enum RadioType: String, Codable {
    case gsm
    case wcdma
    case lte
}

/// Cell tower information (optional, iOS cannot easily access this)
struct CellTower: Codable {
    let radioType: RadioType?
    let mobileCountryCode: UInt16
    let mobileNetworkCode: UInt16
    let locationAreaCode: UInt32
    let cellId: UInt32
    let age: UInt32?
    let asu: UInt8?
}
