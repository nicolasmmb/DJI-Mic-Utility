import DJIMicProtocol
import DJIMicSession
import Foundation
import Observation

@Observable
@MainActor
public final class AppModel {
    public private(set) var snapshot = DeviceSnapshot()
    /// Resolved once per snapshot instead of being rebuilt by every view.
    public private(set) var systemProfile = DeviceSystemProfile.unknown
    public private(set) var pendingSettings: Set<SettingID> = []
    public private(set) var errorMessage: String?
    /// Transmitter currently blinking its LED, if a find is running.
    public private(set) var findingUnit: Int?

    public let notificationSettings: NotificationSettings

    public var diagnosticLines: [DiagnosticLine] { diagnostics.lines }

    private let session: any MicClient
    private let notificationEngine = NotificationRuleEngine()
    private let notifier: any NotificationDelivering
    private var diagnostics = DiagnosticLog()
    private var snapshotTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var errorTask: Task<Void, Never>?
    private var findTask: Task<Void, Never>?

    /// Settings sent but not yet reflected by a device status push. They are
    /// overlaid on every incoming snapshot so a stale push cannot make the UI
    /// jump back to the previous value before the device applies the change.
    private var optimisticSettings: [SettingID: OptimisticEntry] = [:]
    private var lastDeviceSnapshot = DeviceSnapshot()

    private struct OptimisticEntry {
        let setting: MicSetting
        let createdAt: Date
    }

    public init(
        session: any MicClient = MicSession(),
        initialSnapshot: DeviceSnapshot = DeviceSnapshot(),
        notificationSettings: NotificationSettings? = nil,
        notifier: any NotificationDelivering = MicNotificationCenter.shared
    ) {
        self.session = session
        self.snapshot = initialSnapshot
        self.systemProfile = initialSnapshot.systemProfile
        self.lastDeviceSnapshot = initialSnapshot
        self.notificationSettings = notificationSettings ?? NotificationSettings()
        self.notifier = notifier

        MicNotificationCenter.shared.onAction = { [weak self] action in
            self?.handleNotificationAction(action)
        }
        start()
    }

    // MARK: - Lifecycle

    public func start() {
        guard snapshotTask == nil else { return }

        MicNotificationCenter.shared.configure()
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

    public func handleNotificationAction(_ action: MicNotificationAction) {
        switch action {
        case .reconnect:
            reconnect()
        case .rerecord(let unit):
            send(.recording(true, unit: unit))
        }
    }

    private func observeSnapshots() {
        snapshotTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in session.snapshots {
                self.apply(snapshot)
            }
        }
    }

    /// Merges a device snapshot with settings still waiting to be reflected,
    /// so optimistic values are not undone by pushes generated before the
    /// command reached the receiver.
    private func apply(_ incoming: DeviceSnapshot) {
        lastDeviceSnapshot = incoming
        let merged = mergeOptimisticSettings(into: incoming, now: Date())
        snapshot = merged
        systemProfile = merged.systemProfile
        evaluateNotifications(for: merged)
    }

    private func mergeOptimisticSettings(into incoming: DeviceSnapshot, now: Date) -> DeviceSnapshot {
        guard incoming.connection.isConnected else {
            optimisticSettings.removeAll()
            return incoming
        }

        var merged = incoming
        var settled: [SettingID] = []

        for (id, entry) in optimisticSettings {
            let confirmed = incoming.reflects(entry.setting)
            let expired = now.timeIntervalSince(entry.createdAt) > 2.5

            if confirmed || expired {
                settled.append(id)
            } else {
                merged.applyOptimistic(entry.setting)
            }
        }

        for id in settled {
            optimisticSettings[id] = nil
        }
        return merged
    }

    private func evaluateNotifications(for snapshot: DeviceSnapshot) {
        let preferences = notificationSettings.snapshot
        let alerts = notificationEngine.evaluate(
            snapshot: snapshot,
            preferences: preferences
        )

        for alert in alerts {
            Task { [notifier] in
                await notifier.post(alert, preferences: preferences)
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

        if case .recording(false, let unit) = setting {
            notificationEngine.noteUserStoppedRecording(unit: unit)
        }

        pendingSettings.insert(id)
        optimisticSettings[id] = OptimisticEntry(setting: setting, createdAt: Date())
        snapshot.applyOptimistic(setting)

        Task { [weak self] in
            guard let self else { return }
            defer { self.pendingSettings.remove(id) }

            do {
                try await self.session.send(setting)
            } catch {
                self.optimisticSettings[id] = nil
                self.recomposeSnapshotFromLastDeviceState()
                self.showError(SessionErrorMessage.localized(for: error))
            }
        }
    }

    /// Rebuilds the UI snapshot from the last raw device push, keeping only
    /// the optimistic values that are still awaiting confirmation.
    private func recomposeSnapshotFromLastDeviceState() {
        var merged = lastDeviceSnapshot
        for entry in optimisticSettings.values {
            merged.applyOptimistic(entry.setting)
        }
        snapshot = merged
        systemProfile = merged.systemProfile
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
