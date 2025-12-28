import SwiftUI

/// Floating overlay that displays app logs
struct LogOverlayView: View {
    @ObservedObject var logManager = LogManager.shared
    @State private var isExpanded = true
    @State private var dragOffset: CGSize = .zero
    @State private var position: CGPoint = CGPoint(x: 20, y: 100)

    var body: some View {
        if logManager.isOverlayVisible {
            VStack(spacing: 0) {
                // Header bar
                headerBar

                if isExpanded {
                    // Log content
                    logContent

                    // Footer with controls
                    footerBar
                }
            }
            .frame(width: isExpanded ? 340 : 120)
            .background(Color(.systemBackground).opacity(0.95))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray3), lineWidth: 1)
            )
            .position(x: position.x + (isExpanded ? 170 : 60), y: position.y)
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        position.x += value.translation.width
                        position.y += value.translation.height
                        dragOffset = .zero
                    }
            )
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)

            if isExpanded {
                Text("Logs")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(logManager.entries.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }

            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.secondary)
            }

            Button(action: { logManager.isOverlayVisible = false }) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }

    private var logContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(logManager.entries) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .frame(height: 200)
            .onChange(of: logManager.entries.count) { _ in
                if let lastEntry = logManager.entries.last {
                    withAnimation {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var footerBar: some View {
        HStack {
            Button(action: { logManager.clear() }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Clear")
                }
                .font(.caption)
                .foregroundStyle(.red)
            }

            Spacer()

            Button(action: { copyLogs() }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                    Text("Copy")
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private func copyLogs() {
        let logText = logManager.entries.map { entry in
            let source = entry.source.map { "[\($0)] " } ?? ""
            return "\(entry.formattedTime) \(entry.level.rawValue) \(source)\(entry.message)"
        }.joined(separator: "\n")

        UIPasteboard.general.string = logText
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.level.emoji)
                .font(.system(size: 10))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.formattedTime)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)

                    if let source = entry.source {
                        Text(source)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(sourceColor)
                    }
                }

                Text(entry.message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(messageColor)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }

    private var messageColor: Color {
        switch entry.level {
        case .debug: return .secondary
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        }
    }

    private var sourceColor: Color {
        .blue.opacity(0.8)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        LogOverlayView()
            .onAppear {
                LogManager.shared.isOverlayVisible = true
                LogManager.shared.info("App started", source: "App")
                LogManager.shared.debug("Checking permissions", source: "Location")
                LogManager.shared.info("Connected to server", source: "LAN")
                LogManager.shared.warning("Weak signal detected", source: "BLE")
                LogManager.shared.error("Connection failed: timeout", source: "Transport")
            }
    }
}
