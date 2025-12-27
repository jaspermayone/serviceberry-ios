import Foundation

/// Information about a discovered Serviceberry server
struct ServerInfo: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let host: String
    let port: UInt16
    let certFingerprint: String
    let version: String
    let paths: [String]

    init(name: String, host: String, port: UInt16, certFingerprint: String, version: String, paths: [String]) {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.certFingerprint = certFingerprint
        self.version = version
        self.paths = paths
    }

    /// Base URL for API requests
    var baseURL: URL? {
        URL(string: "https://\(host):\(port)")
    }

    /// Submit endpoint URL
    var submitURL: URL? {
        baseURL?.appendingPathComponent(Constants.submitPath)
    }

    /// Request endpoint URL
    var requestURL: URL? {
        baseURL?.appendingPathComponent(Constants.requestPath)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(host)
        hasher.combine(port)
    }

    static func == (lhs: ServerInfo, rhs: ServerInfo) -> Bool {
        lhs.host == rhs.host && lhs.port == rhs.port
    }
}
