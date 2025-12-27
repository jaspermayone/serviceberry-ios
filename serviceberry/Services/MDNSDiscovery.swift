import Foundation
import Network
import Combine

/// Service for discovering Serviceberry servers via mDNS/Bonjour
@MainActor
class MDNSDiscovery: ObservableObject {
    private var browser: NWBrowser?
    private var connections: [NWConnection] = []

    @Published var discoveredServers: [ServerInfo] = []
    @Published var isSearching = false
    @Published var lastError: Error?

    /// Start browsing for Serviceberry servers
    func startBrowsing() {
        stopBrowsing()
        discoveredServers = []
        isSearching = true

        let descriptor = NWBrowser.Descriptor.bonjour(
            type: Constants.bonjourServiceType,
            domain: Constants.bonjourDomain
        )

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: descriptor, using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    break
                case .failed(let error):
                    self.lastError = error
                    self.isSearching = false
                case .cancelled:
                    self.isSearching = false
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.processBrowseResults(results)
            }
        }

        browser?.start(queue: .main)
    }

    /// Stop browsing
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        for conn in connections {
            conn.cancel()
        }
        connections = []
        isSearching = false
    }

    private func processBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            guard case .service(let name, let type, let domain, _) = result.endpoint else { continue }

            // Extract TXT records from metadata
            var version = "unknown"
            var paths: [String] = []
            var certFingerprint = ""

            if case .bonjour(let txtRecord) = result.metadata {
                let dict = parseTXTRecord(txtRecord)
                version = dict["version"] ?? "unknown"
                certFingerprint = dict["cert_fingerprint"] ?? ""
                if let pathsStr = dict["paths"] {
                    paths = pathsStr.components(separatedBy: ", ")
                }
            }

            // Resolve the service to get the actual host
            resolveService(
                name: name,
                type: type,
                domain: domain,
                version: version,
                paths: paths,
                certFingerprint: certFingerprint
            )
        }
    }

    private func resolveService(
        name: String,
        type: String,
        domain: String,
        version: String,
        paths: [String],
        certFingerprint: String
    ) {
        // Create a connection to resolve the service endpoint
        let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
        let parameters = NWParameters.tcp
        let connection = NWConnection(to: endpoint, using: parameters)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch state {
                case .ready:
                    // Get the resolved endpoint
                    if let resolvedEndpoint = connection.currentPath?.remoteEndpoint {
                        self.handleResolvedEndpoint(
                            resolvedEndpoint,
                            serviceName: name,
                            version: version,
                            paths: paths,
                            certFingerprint: certFingerprint
                        )
                    }
                    connection.cancel()

                case .failed, .cancelled:
                    connection.cancel()

                default:
                    break
                }
            }
        }

        connections.append(connection)
        connection.start(queue: .main)
    }

    private func handleResolvedEndpoint(
        _ endpoint: NWEndpoint,
        serviceName: String,
        version: String,
        paths: [String],
        certFingerprint: String
    ) {
        var host: String = ""
        var port: UInt16 = Constants.serverPort

        switch endpoint {
        case .hostPort(let h, let p):
            port = p.rawValue

            switch h {
            case .name(let hostname, _):
                // Use the resolved hostname (e.g., "turtle.local")
                host = hostname
            case .ipv4(let addr):
                // Use IPv4 address
                host = "\(addr)"
            case .ipv6(let addr):
                // Use IPv6 address
                host = "[\(addr)]"
            @unknown default:
                break
            }

        default:
            break
        }

        guard !host.isEmpty else { return }

        let serverInfo = ServerInfo(
            name: serviceName,
            host: host,
            port: port,
            certFingerprint: certFingerprint,
            version: version,
            paths: paths
        )

        // Add if not already discovered (by host)
        if !discoveredServers.contains(where: { $0.host == host }) {
            discoveredServers.append(serverInfo)
        }
    }

    private func parseTXTRecord(_ record: NWTXTRecord) -> [String: String] {
        var dict: [String: String] = [:]
        for key in record.dictionary.keys {
            if let value = record.dictionary[key] {
                dict[key] = value
            }
        }
        return dict
    }
}
