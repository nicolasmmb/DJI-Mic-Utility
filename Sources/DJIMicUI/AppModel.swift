import DJIMicProtocol
import DJIMicSession
import Foundation
import Observation

public struct DiagnosticLine: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let text: String
}

@Observable
@MainActor
public final class AppModel {
    public private(set) var snapshot = DeviceSnapshot()
    public private(set) var pendingSettings: Set<SettingID> = []
    public private(set) var errorMessage: String?
    public private(set) var diagnosticLines: [DiagnosticLine] = []
    /// Transmitter currently blinking its LED, if a find is running.
    public private(set) var findingUnit: Int?

    private let session: any MicClient
    private var snapshotTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var errorTask: Task<Void, Never>?
    private var findTask: Task<Void, Never>?

    public init(
        session: any MicClient = MicSession(),
        initialSnapshot: DeviceSnapshot = DeviceSnapshot()
    ) {
        self.session = session
        self.snapshot = initialSnapshot
        start()
    }

    public func start() {
        guard snapshotTask == nil else { return }

        session.start()

        snapshotTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in session.snapshots {
                self.snapshot = snapshot
            }
        }

        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in session.events {
                self.handle(event)
            }
        }
    }

    public func stop() {
        snapshotTask?.cancel()
        eventTask?.cancel()
        findTask?.cancel()
        snapshotTask = nil
        eventTask = nil
        findTask = nil
        findingUnit = nil
        session.stop()
    }

    public func reconnect() {
        errorMessage = nil
        session.reconnect()
        appendDiagnostic("Reconnect requested")
    }

    public func send(_ setting: MicSetting) {
        let id = setting.id
        guard !pendingSettings.contains(id) else { return }
        // A find owns the LEDs while it runs; do not fight its animation.
        if findingUnit != nil, id == .micLED { return }

        pendingSettings.insert(id)
        applyOptimistic(setting)
        Task {
            defer { pendingSettings.remove(id) }
            do {
                try await session.send(setting)
            } catch {
                showError(localizedMessage(for: error))
            }
        }
    }

    /// Settings UI should react on the same frame as the click. The device
    /// status pushes (about 10 Hz) reconcile this optimistic value almost
    /// immediately, and a rejected command naturally reverts on the next push.
    private func applyOptimistic(_ setting: MicSetting) {
        switch setting {
        case .gain(let value):
            snapshot.receiver?.gain = value
        case .monitoringGain(let value):
            snapshot.receiver?.monitoringGain = value
        case .safetyTrack(let value):
            snapshot.receiver?.safetyTrack = value
        case .stereo(let value):
            snapshot.receiver?.stereo = value
        case .lowCut(let value):
            for unit in snapshot.transmitters.keys {
                snapshot.transmitters[unit]?.lowCut = value
            }
        case .micLED(let value, let unit):
            if let unit {
                snapshot.transmitters[unit]?.ledsOff = !value
            } else {
                for unit in snapshot.transmitters.keys {
                    snapshot.transmitters[unit]?.ledsOff = !value
                }
            }
        case .voiceTone(let tone, let unit):
            snapshot.transmitters[unit]?.voiceTone = tone
        case .clippingControl(let value):
            snapshot.receiver?.clippingControl = value
            for unit in snapshot.transmitters.keys {
                snapshot.transmitters[unit]?.clippingControl = value
            }
        case .autoOffTX(let value):
            for unit in snapshot.transmitters.keys {
                snapshot.transmitters[unit]?.autoOff = value
            }
        case .autoOffRX(let value):
            snapshot.receiver?.autoOff = value
        }
    }

    /// Blinks one transmitter's LED so the user can identify the physical unit.
    ///
    /// The mic LED command is a persistent toggle, not a momentary blink, so
    /// the state captured before the animation is always written back: on
    /// completion, on cancellation and after a rejected command.
    @discardableResult
    public func findTransmitter(
        unit: Int,
        blinks: Int = 4,
        interval: Duration = .milliseconds(350)
    ) -> Task<Void, Never>? {
        guard snapshot.connection.isConnected,
              snapshot.transmitters[unit] != nil,
              findingUnit == nil else { return nil }

        let originalLEDsOff = snapshot.transmitters[unit]?.ledsOff ?? false
        findingUnit = unit
        appendDiagnostic("Find transmitter \(unit) started")

        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.findingUnit = nil
                self.findTask = nil
                self.appendDiagnostic("Find transmitter \(unit) finished")
            }

            var failure: Error?
            do {
                for _ in 0..<max(1, blinks) {
                    try Task.checkCancellation()
                    try await self.session.send(.micLED(true, unit: unit))
                    try await Task.sleep(for: interval)
                    try Task.checkCancellation()
                    try await self.session.send(.micLED(false, unit: unit))
                    try await Task.sleep(for: interval)
                }
            } catch is CancellationError {
                // Restore below.
            } catch {
                failure = error
            }

            // `send` does not observe cancellation, so the restore still runs
            // when the panel closes mid-animation.
            do {
                try await self.session.send(.micLED(!originalLEDsOff, unit: unit))
            } catch is CancellationError {
                // Nothing to recover here; the command was already sent.
            } catch {
                if failure == nil { failure = error }
            }

            if let failure {
                self.showError(self.localizedMessage(for: failure))
            }
        }
        findTask = task
        return task
    }

    public func isPending(_ id: SettingID) -> Bool {
        pendingSettings.contains(id)
    }

    public func clearDiagnostics() {
        diagnosticLines.removeAll()
    }

    public func diagnosticsJSONL() -> String {
        let formatter = ISO8601DateFormatter()
        return diagnosticLines.map { line in
            let text = line.text.replacingOccurrences(of: "\"", with: "\\\"")
            return "{\"timestamp\":\"\(formatter.string(from: line.timestamp))\",\"message\":\"\(text)\"}"
        }.joined(separator: "\n") + (diagnosticLines.isEmpty ? "" : "\n")
    }

    private func handle(_ event: SessionEvent) {
        switch event {
        case .log(let message):
            appendDiagnostic(message)
        case .frame(let raw, let summary):
            let hex = raw.map { String(format: "%02x", $0) }.joined(separator: " ")
            appendDiagnostic("\(summary) | \(hex)")
        }
    }

    private func appendDiagnostic(_ text: String) {
        diagnosticLines.append(DiagnosticLine(timestamp: Date(), text: text))
        if diagnosticLines.count > 400 {
            diagnosticLines.removeFirst(diagnosticLines.count - 400)
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        errorTask?.cancel()
        errorTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.errorMessage = nil
        }
    }

    private func localizedMessage(for error: Error) -> String {
        guard let sessionError = error as? MicSessionError else {
            return L10n.format("error.unknown", String(describing: error))
        }

        switch sessionError {
        case .disconnected:
            return L10n.s("error.disconnected")
        case .timeout:
            return L10n.s("error.timeout")
        case .rejected:
            return L10n.s("error.rejected")
        case .transport(let message):
            return L10n.format("error.transport", message)
        }
    }
}
