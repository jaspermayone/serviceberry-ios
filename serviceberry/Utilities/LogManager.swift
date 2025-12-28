import Foundation
import Combine
import OSLog

/// Log level for categorizing messages
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

/// A single log entry
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let source: String?

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

/// Global log manager for the app
@MainActor
class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published private(set) var entries: [LogEntry] = []
    @Published var isOverlayVisible: Bool = false

    private let maxEntries = 500

    // OSLog loggers for Console.app streaming
    private let defaultLogger = Logger(subsystem: "org.limeskey.serviceberry", category: "app")
    private var loggers: [String: Logger] = [:]

    private init() {}

    private func logger(for source: String?) -> Logger {
        guard let source = source else { return defaultLogger }
        if let existing = loggers[source] {
            return existing
        }
        let newLogger = Logger(subsystem: "org.limeskey.serviceberry", category: source)
        loggers[source] = newLogger
        return newLogger
    }

    func log(_ message: String, level: LogLevel = .info, source: String? = nil) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message, source: source)
        entries.append(entry)

        // Trim old entries if needed
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        // Send to OSLog for Console.app streaming
        let osLogger = logger(for: source)
        osLogger.log(level: level.osLogType, "\(message)")

        // Also print to console for Xcode debugging
        let sourcePrefix = source.map { "[\($0)] " } ?? ""
        print("\(entry.formattedTime) \(level.emoji) \(sourcePrefix)\(message)")
    }

    func debug(_ message: String, source: String? = nil) {
        log(message, level: .debug, source: source)
    }

    func info(_ message: String, source: String? = nil) {
        log(message, level: .info, source: source)
    }

    func warning(_ message: String, source: String? = nil) {
        log(message, level: .warning, source: source)
    }

    func error(_ message: String, source: String? = nil) {
        log(message, level: .error, source: source)
    }

    func clear() {
        entries.removeAll()
    }

    func toggleOverlay() {
        isOverlayVisible.toggle()
    }
}

/// Convenience global logging functions
@MainActor
func appLog(_ message: String, level: LogLevel = .info, source: String? = nil) {
    LogManager.shared.log(message, level: level, source: source)
}
