import Foundation
internal import CoreLocation

/// Position data matching the server's expected format
struct Position: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let altitude: Double
    let altitudeAccuracy: Double
    let heading: Double
    let speed: Double
    let source: String

    /// Create Position from CLLocation
    init(from location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.accuracy = location.horizontalAccuracy
        self.altitude = location.altitude
        self.altitudeAccuracy = location.verticalAccuracy
        self.heading = location.course >= 0 ? location.course : 0
        self.speed = location.speed >= 0 ? location.speed : 0
        self.source = "gps"
    }

    /// Manual initializer for testing
    init(latitude: Double, longitude: Double, accuracy: Double, altitude: Double = 0,
         altitudeAccuracy: Double = 0, heading: Double = 0, speed: Double = 0, source: String = "gps") {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.altitude = altitude
        self.altitudeAccuracy = altitudeAccuracy
        self.heading = heading
        self.speed = speed
        self.source = source
    }
}
