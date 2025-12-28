import Foundation
import Network
import Combine

/// Service for discovering Serviceberry servers via mDNS/Bonjour
/// Delegate for NetService resolution
class ServiceResolverDelegate: NSObject, NetServiceDelegate {
    private let completion: (String?, UInt16) -> Void

    init(completion: @escaping (String?, UInt16) -> Void) {
        self.completion = completion
        super.init()
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let host = sender.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")) ?? sender.hostName
        let port = UInt16(sender.port)
        completion(host, port)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        LogManager.shared.error("NetService resolution error: \(errorDict)", source: "mDNS")
        completion(nil, 0)
    }
}

@MainActor
class MDNSDiscovery: ObservableObject {
    private var browser: NWBrowser?
    private var connections: [NWConnection] = []
    private var activeNetServices: [NetService] = []
    private var resolverDelegates: [ServiceResolverDelegate] = []

    @Published var discoveredServers: [ServerInfo] = []
    @Published var isSearching = false
    @Published var lastError: Error?
    @Published var debugState: String = "idle"
    private var retryCount = 0
    private let maxRetries = 3

    /// Start browsing for Serviceberry servers
    func startBrowsing() {
        retryCount = 0
        startBrowsingInternal()
    }

    private func startBrowsingInternal() {
        stopBrowsing()
        discoveredServers = []
        isSearching = true
        debugState = "starting"

        // Use nil domain to search all local domains
        let descriptor = NWBrowser.Descriptor.bonjour(
            type: Constants.bonjourServiceType,
            domain: nil
        )

        // Use default parameters for mDNS browsing
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        LogManager.shared.info("Starting mDNS browser for: \(Constants.bonjourServiceType)", source: "mDNS")
        browser = NWBrowser(for: descriptor, using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    LogManager.shared.info("Browser ready", source: "mDNS")
                    self.debugState = "ready"
                case .failed(let error):
                    LogManager.shared.error("Browser failed: \(error.localizedDescription)", source: "mDNS")
                    self.debugState = "failed: \(error.localizedDescription)"
                    self.lastError = error
                    self.isSearching = false
                    // Auto-retry after 2 seconds on failure (up to maxRetries)
                    if self.retryCount < self.maxRetries {
                        self.retryCount += 1
                        self.debugState = "retrying (\(self.retryCount)/\(self.maxRetries))..."
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            LogManager.shared.info("Auto-retrying (\(self.retryCount)/\(self.maxRetries))...", source: "mDNS")
                            self.startBrowsingInternal()
                        }
                    }
                case .cancelled:
                    LogManager.shared.debug("Browser cancelled", source: "mDNS")
                    self.debugState = "cancelled"
                    self.isSearching = false
                case .waiting(let error):
                    LogManager.shared.warning("Browser waiting: \(error.localizedDescription)", source: "mDNS")
                    self.debugState = "waiting: \(error.localizedDescription)"
                case .setup:
                    LogManager.shared.debug("Browser setup...", source: "mDNS")
                    self.debugState = "setup"
                @unknown default:
                    LogManager.shared.warning("Browser unknown state", source: "mDNS")
                    self.debugState = "unknown"
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                LogManager.shared.info("Found \(results.count) service(s)", source: "mDNS")
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
        for service in activeNetServices {
            service.stop()
        }
        activeNetServices = []
        resolverDelegates = []
        isSearching = false
        debugState = "stopped"
    }

    private func processBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            guard case .service(let name, let type, let domain, _) = result.endpoint else { continue }
            LogManager.shared.debug("Service: '\(name)' type: '\(type)' domain: '\(domain)'", source: "mDNS")

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
                LogManager.shared.debug("TXT: \(dict)", source: "mDNS")
            }

            // Resolve the service to get actual hostname
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
        LogManager.shared.debug("Resolving service '\(name)'...", source: "mDNS")

        // Use NetService for resolution (more reliable than NWConnection for mDNS)
        let netService = NetService(domain: domain, type: type, name: name)
        let delegate = ServiceResolverDelegate { [weak self] host, port in
            Task { @MainActor in
                guard let self = self else { return }

                if let host = host {
                    LogManager.shared.info("Resolved '\(name)' -> \(host):\(port)", source: "mDNS")

                    let serverInfo = ServerInfo(
                        name: name,
                        host: host,
                        port: port,
                        certFingerprint: certFingerprint,
                        version: version,
                        paths: paths
                    )

                    if !self.discoveredServers.contains(where: { $0.host == host }) {
                        self.discoveredServers.append(serverInfo)
                    }
                } else {
                    LogManager.shared.warning("Failed to resolve '\(name)'", source: "mDNS")
                }
            }
        }

        // Store delegate to prevent deallocation
        resolverDelegates.append(delegate)
        netService.delegate = delegate
        netService.resolve(withTimeout: 10.0)
        activeNetServices.append(netService)
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
                // Use IPv4 address, strip any interface suffix (e.g., %en0)
                var ipStr = "\(addr)"
                if let percentIndex = ipStr.firstIndex(of: "%") {
                    ipStr = String(ipStr[..<percentIndex])
                }
                host = ipStr
            case .ipv6(let addr):
                // Use IPv6 address, strip any interface suffix
                var ipStr = "\(addr)"
                if let percentIndex = ipStr.firstIndex(of: "%") {
                    ipStr = String(ipStr[..<percentIndex])
                }
                host = "[\(ipStr)]"
            @unknown default:
                break
            }

        default:
            break
        }

        guard !host.isEmpty else {
            LogManager.shared.warning("Failed to resolve host for '\(serviceName)'", source: "mDNS")
            return
        }

        LogManager.shared.info("Resolved '\(serviceName)' -> \(host):\(port)", source: "mDNS")

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
