import Foundation

public struct DiagnosticLine: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let text: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
    }
}

/// Bounded, append-only log for the diagnostics window.
struct DiagnosticLog {
    static let capacity = 400

    private static let jsonDateFormatter = ISO8601DateFormatter()

    private(set) var lines: [DiagnosticLine] = []

    mutating func append(_ text: String, at date: Date = Date()) {
        lines.append(DiagnosticLine(timestamp: date, text: text))
        trimOverflow()
    }

    mutating func clear() {
        lines.removeAll(keepingCapacity: true)
    }

    /// One JSON object per line, suitable for `diagnostics.jsonl` exports.
    func jsonLines() -> String {
        guard !lines.isEmpty else { return "" }
        return lines.map(Self.jsonLine).joined(separator: "\n") + "\n"
    }

    private mutating func trimOverflow() {
        let overflow = lines.count - Self.capacity
        guard overflow > 0 else { return }
        lines.removeFirst(overflow)
    }

    private static func jsonLine(_ line: DiagnosticLine) -> String {
        let escapedText = line.text.replacingOccurrences(of: "\"", with: "\\\"")
        let timestamp = jsonDateFormatter.string(from: line.timestamp)
        return #"{"timestamp":"\#(timestamp)","message":"\#(escapedText)"}"#
    }
}
