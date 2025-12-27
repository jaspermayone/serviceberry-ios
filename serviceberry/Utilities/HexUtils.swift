import Foundation
import CryptoKit

enum HexUtils {
    /// Convert Data to lowercase hex string
    static func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /// Compute SHA256 hash of data and return as hex string
    static func sha256Hex(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Compare two hex fingerprints (case-insensitive)
    static func fingerprintsMatch(_ a: String, _ b: String) -> Bool {
        a.lowercased() == b.lowercased()
    }
}
