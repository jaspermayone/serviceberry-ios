import Foundation
import Combine
import CryptoKit

/// LAN transport for communicating with Serviceberry server over HTTPS
class LANTransport: NSObject, ObservableObject, TransportProtocol {
    private var session: URLSession!
    private let serverInfo: ServerInfo
    private var pollingTask: Task<Void, Never>?

    @Published private(set) var connectionState: ConnectionState = .disconnected

    var onLocationRequest: (() async -> Void)?

    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    init(serverInfo: ServerInfo) {
        self.serverInfo = serverInfo
        super.init()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func connect() async throws {
        updateState(.connecting)

        // Test connection by hitting status endpoint
        guard let statusURL = serverInfo.baseURL?.appendingPathComponent(Constants.statusPath) else {
            throw TransportError.connectionFailed("Invalid server URL")
        }

        do {
            let (_, response) = try await session.data(from: statusURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw TransportError.connectionFailed("Server returned error")
            }

            updateState(.connected)
            startPolling()
        } catch {
            updateState(.error(error.localizedDescription))
            throw error
        }
    }

    func disconnect() {
        pollingTask?.cancel()
        pollingTask = nil
        updateState(.disconnected)
    }

    func sendLocation(_ payload: LocationPayload) async throws {
        guard connectionState.isConnected else {
            throw TransportError.notConnected
        }

        guard let submitURL = serverInfo.submitURL else {
            throw TransportError.sendFailed("Invalid submit URL")
        }

        var request = URLRequest(url: submitURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TransportError.sendFailed("Server returned error")
        }
    }

    private func startPolling() {
        pollingTask?.cancel()

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollForRequest()
                try? await Task.sleep(nanoseconds: UInt64(Constants.requestPollInterval * 1_000_000_000))
            }
        }
    }

    private func pollForRequest() async {
        guard let requestURL = serverInfo.requestURL else { return }

        do {
            let (data, response) = try await session.data(from: requestURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            // Check if server is requesting location
            if let responseText = String(data: data, encoding: .utf8),
               responseText.lowercased().contains("request") {
                await onLocationRequest?()
            }
        } catch {
            // Polling error - don't disconnect, just log
            print("Polling error: \(error.localizedDescription)")
        }
    }

    private func updateState(_ state: ConnectionState) {
        Task { @MainActor in
            connectionState = state
            connectionStateSubject.send(state)
        }
    }
}

// MARK: - URLSessionDelegate for Certificate Pinning
extension LANTransport: URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // If no fingerprint provided, trust any certificate (for local network use)
        if serverInfo.certFingerprint.isEmpty {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }

        // Get the server certificate
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let serverCert = certificateChain.first else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Get certificate data and compute fingerprint
        let certData = SecCertificateCopyData(serverCert) as Data
        let serverFingerprint = HexUtils.sha256Hex(of: certData)

        // Compare with expected fingerprint
        if HexUtils.fingerprintsMatch(serverFingerprint, serverInfo.certFingerprint) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            print("Certificate mismatch!")
            print("Expected: \(serverInfo.certFingerprint)")
            print("Got: \(serverFingerprint)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
