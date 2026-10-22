import DJIMicProtocol
import DJIMicSession
import Foundation
import Observation

@Observable
@MainActor
public final class AppModel {
    public private(set) var snapshot = DeviceSnapshot()
    public private(set) var pendingSettings: Set<SettingID> = []
    public private(set) var errorMessage: String?
    /// Transmitter currently blinking its LED, if a find is running.
    public private(set) var findingUnit: Int?

    public var diagnosticLines: [DiagnosticLine] { diagnostics.lines }

    private let session: any MicClient
    private var diagnostics = DiagnosticLog()
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

    // MARK: - Lifecycle

    public func start() {
        guard snapshotTask == nil else { return }

        session.start()
        observeSnapshots()
        observeEvents()
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

    private func observeSnapshots() {
        snapshotTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in session.snapshots {
                self.snapshot = snapshot
            }
        }
    }

    private func observeEvents() {
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in session.events {
                self.handle(event)
            }
        }
    }

    // MARK: - Settings

    public func send(_ setting: MicSetting) {
        let id = setting.id
        guard canSend(id) else { return }

        pendingSettings.insert(id)
        snapshot.applyOptimistic(setting)

        Task { [weak self] in
            guard let self else { return }
            defer { self.pendingSettings.remove(id) }

            do {
                try await self.session.send(setting)
            } catch {
                self.showError(SessionErrorMessage.localized(for: error))
            }
        }
    }

    public func isPending(_ id: SettingID) -> Bool {
        pendingSettings.contains(id)
    }

    private func canSend(_ id: SettingID) -> Bool {
        guard !pendingSettings.contains(id) else { return false }
        // A find owns the LEDs while it runs; do not fight its animation.
        return findingUnit == nil || id != .micLED
    }

    // MARK: - Find transmitter

    /// Blinks one transmitter's LED so the user can identify the physical unit.
    /// Returns `nil` when the device is disconnected or a find is already
    /// running.
    @discardableResult
    public func findTransmitter(
        unit: Int,
        blinks: Int = 4,
        interval: Duration = .milliseconds(350)
    ) -> Task<Void, Never>? {
        guard canFind(unit: unit) else { return nil }

        let originalLEDsOff = snapshot.transmitters[unit]?.ledsOff ?? false
        findingUnit = unit
        appendDiagnostic("Find transmitter \(unit) started")

        let sequencer = FindTransmitterSequencer(
            unit: unit,
            blinks: blinks,
            interval: interval,
            send: { [session] setting in try await session.send(setting) }
        )

        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.finishFind(unit: unit) }

            do {
                try await sequencer.run(originallyOff: originalLEDsOff)
            } catch {
                self.showError(SessionErrorMessage.localized(for: error))
            }
        }

        findTask = task
        return task
    }

    private func canFind(unit: Int) -> Bool {
        snapshot.connection.isConnected
            && snapshot.transmitters[unit] != nil
            && findingUnit == nil
    }

    private func finishFind(unit: Int) {
        findingUnit = nil
        findTask = nil
        appendDiagnostic("Find transmitter \(unit) finished")
    }

    // MARK: - Diagnostics

    public func clearDiagnostics() {
        diagnostics.clear()
    }

    public func diagnosticsJSONL() -> String {
        diagnostics.jsonLines()
    }

    private func handle(_ event: SessionEvent) {
        switch event {
        case .log(let message):
            appendDiagnostic(message)
        case .frame(let raw, let summary):
            appendDiagnostic("\(summary) | \(Self.hexString(raw))")
        }
    }

    private func appendDiagnostic(_ text: String) {
        diagnostics.append(text)
    }

    private static func hexString(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    // MARK: - Errors

    private func showError(_ message: String) {
        errorMessage = message
        errorTask?.cancel()
        errorTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.errorMessage = nil
        }
    }
}
