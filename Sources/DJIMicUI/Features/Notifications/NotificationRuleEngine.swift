import DJIMicProtocol
import Foundation

/// Pure-ish state machine that turns device snapshots into notification
/// events. Timers are driven by the `now` passed into `evaluate` so it can be
/// tested without sleeping.
public final class NotificationRuleEngine {
    public struct Timing: Sendable {
        public var receiverConnectDelay: TimeInterval
        public var transmitterConnectDelay: TimeInterval
        public var disconnectDelay: TimeInterval
        public var recordingStopDelay: TimeInterval
        public var linkLostDelay: TimeInterval
        public var connectGroupWindow: TimeInterval
        public var batteryCooldown: TimeInterval
        public var disconnectCooldown: TimeInterval
        public var recordingStopCooldown: TimeInterval
        public var linkLostCooldown: TimeInterval
        public var userStopSuppression: TimeInterval

        public init(
            receiverConnectDelay: TimeInterval = 2,
            transmitterConnectDelay: TimeInterval = 3,
            disconnectDelay: TimeInterval = 3,
            recordingStopDelay: TimeInterval = 2,
            linkLostDelay: TimeInterval = 2,
            connectGroupWindow: TimeInterval = 5,
            batteryCooldown: TimeInterval = 15 * 60,
            disconnectCooldown: TimeInterval = 2 * 60,
            recordingStopCooldown: TimeInterval = 30,
            linkLostCooldown: TimeInterval = 60,
            userStopSuppression: TimeInterval = 2
        ) {
            self.receiverConnectDelay = receiverConnectDelay
            self.transmitterConnectDelay = transmitterConnectDelay
            self.disconnectDelay = disconnectDelay
            self.recordingStopDelay = recordingStopDelay
            self.linkLostDelay = linkLostDelay
            self.connectGroupWindow = connectGroupWindow
            self.batteryCooldown = batteryCooldown
            self.disconnectCooldown = disconnectCooldown
            self.recordingStopCooldown = recordingStopCooldown
            self.linkLostCooldown = linkLostCooldown
            self.userStopSuppression = userStopSuppression
        }
    }

    private struct UnitState {
        var presentSince: Date?
        var absentSince: Date?
        var wasPresent = false
        var connectedAnnounced = false
        var wasRecording = false
        var userStopAt: Date?
        var recordingStopPendingSince: Date?
        var recordingStopWasUserInitiated = false
        var lastDisconnectedAt: Date?
        var lastRecordingStopAt: Date?
        var batteryLowActive = false
        var lastBatteryLowAt: Date?
    }

    private let timing: Timing
    private var units: [Int: UnitState] = [:]

    private var primed = false
    private var rxWasConnected = false
    private var rxConnectedSince: Date?
    private var rxDisconnectedSince: Date?
    private var rxConnectedAnnounced = false
    private var rxConnectedAnnouncedAt: Date?
    private var linkLostAnnounced = false
    private var lastLinkLostAt: Date?

    public init(timing: Timing = Timing()) {
        self.timing = timing
    }

    /// Called by AppModel when the user (or a preset) asks a TX to stop
    /// recording, so that intentional stops do not raise an alert.
    public func noteUserStoppedRecording(unit: Int, at date: Date = Date()) {
        units[unit, default: UnitState()].userStopAt = date
    }

    public func evaluate(
        snapshot: DeviceSnapshot,
        preferences: NotificationPreferences,
        now: Date = Date()
    ) -> [MicAlert] {
        var alerts: [MicAlert] = []
        let connected = snapshot.connection.isConnected
        let receiverName = snapshot.receiverDisplayName

        if !primed {
            primed = true
            if connected {
                rxWasConnected = true
                rxConnectedSince = now
                rxConnectedAnnounced = !preferences.notifyOnLaunchWhenConnected
                for unit in snapshot.transmitters.keys {
                    var state = units[unit, default: UnitState()]
                    state.wasPresent = true
                    state.presentSince = now
                    state.connectedAnnounced = !preferences.notifyOnLaunchWhenConnected
                    state.wasRecording = snapshot.transmitters[unit]?.isRecording ?? false
                    units[unit] = state
                }
            }
            return []
        }

        if connected {
            rxDisconnectedSince = nil
            linkLostAnnounced = false

            if !rxWasConnected {
                rxWasConnected = true
                rxConnectedSince = now
                rxConnectedAnnounced = false
                rxConnectedAnnouncedAt = nil
                for unit in units.keys {
                    units[unit]?.wasPresent = false
                    units[unit]?.presentSince = nil
                    units[unit]?.connectedAnnounced = false
                    units[unit]?.absentSince = nil
                    units[unit]?.wasRecording = false
                    units[unit]?.userStopAt = nil
                    units[unit]?.recordingStopPendingSince = nil
                    units[unit]?.recordingStopWasUserInitiated = false
                }
            }

            if let since = rxConnectedSince,
               !rxConnectedAnnounced,
               now.timeIntervalSince(since) >= timing.receiverConnectDelay {
                if preferences.receiverConnected {
                    alerts.append(.receiverConnected(name: receiverName))
                }
                rxConnectedAnnounced = true
                rxConnectedAnnouncedAt = now
            }

            alerts.append(contentsOf: evaluateTransmitters(
                snapshot: snapshot,
                preferences: preferences,
                now: now
            ))
            return preferences.enabled ? alerts : []
        }

        // Receiver/USB is down: only the link-lost alert is meaningful.
        if rxWasConnected {
            rxWasConnected = false
            rxDisconnectedSince = now
            rxConnectedSince = nil
            rxConnectedAnnounced = false
            rxConnectedAnnouncedAt = nil
        }

        if let since = rxDisconnectedSince,
           !linkLostAnnounced,
           now.timeIntervalSince(since) >= timing.linkLostDelay {
            let canNotify = lastLinkLostAt.map {
                now.timeIntervalSince($0) >= timing.linkLostCooldown
            } ?? true

            if preferences.linkLost && canNotify {
                alerts.append(.linkLost(receiverName: receiverName))
                lastLinkLostAt = now
            }
            linkLostAnnounced = true
        }

        for unit in units.keys {
            units[unit]?.wasPresent = false
            units[unit]?.presentSince = nil
            units[unit]?.connectedAnnounced = false
            units[unit]?.absentSince = nil
            units[unit]?.wasRecording = false
            units[unit]?.userStopAt = nil
            units[unit]?.recordingStopPendingSince = nil
            units[unit]?.recordingStopWasUserInitiated = false
        }

        return preferences.enabled ? alerts : []
    }

    private func evaluateTransmitters(
        snapshot: DeviceSnapshot,
        preferences: NotificationPreferences,
        now: Date
    ) -> [MicAlert] {
        var alerts: [MicAlert] = []
        var known = Set(units.keys)
        known.formUnion(snapshot.transmitters.keys)
        known.formUnion(snapshot.transmitterIdentities.keys)

        for unit in known.sorted() {
            var state = units[unit, default: UnitState()]
            let transmitter = snapshot.transmitters[unit]
            let name = snapshot.transmitterDisplayName(unit: unit)

            guard let transmitter else {
                if state.wasPresent {
                    state.wasPresent = false
                    state.presentSince = nil
                    state.absentSince = now
                    state.connectedAnnounced = false
                    state.wasRecording = false
                }

                if let absentSince = state.absentSince,
                   now.timeIntervalSince(absentSince) >= timing.disconnectDelay {
                    let canNotify = state.lastDisconnectedAt.map {
                        now.timeIntervalSince($0) >= timing.disconnectCooldown
                    } ?? true

                    if preferences.transmitterDisconnected && canNotify {
                        alerts.append(.transmitterDisconnected(unit: unit, name: name))
                        state.lastDisconnectedAt = now
                    }
                    state.absentSince = nil
                }

                // Keep the low-battery cooldown across brief dropouts so a
                // reconnect does not repeat the same alert.
                state.recordingStopPendingSince = nil
                state.recordingStopWasUserInitiated = false
                units[unit] = state
                continue
            }

            if !state.wasPresent {
                state.wasPresent = true
                state.presentSince = now
                state.absentSince = nil
                state.connectedAnnounced = false
            }

            if state.presentSince == nil {
                state.presentSince = now
            }

            if !state.connectedAnnounced,
               let presentSince = state.presentSince,
               now.timeIntervalSince(presentSince) >= timing.transmitterConnectDelay {
                let inGroupWindow = rxConnectedAnnouncedAt.map {
                    now.timeIntervalSince($0) < timing.connectGroupWindow
                } ?? false

                if !inGroupWindow {
                    if preferences.transmitterConnected {
                        alerts.append(.transmitterConnected(
                            unit: unit,
                            name: name,
                            batteryGauge: transmitter.batteryGauge,
                            charging: transmitter.charging
                        ))
                    }
                    state.connectedAnnounced = true
                }
            }

            if transmitter.batteryGauge >= 6 && !transmitter.charging {
                let canNotify = !state.batteryLowActive ||
                    (state.lastBatteryLowAt.map {
                        now.timeIntervalSince($0) >= timing.batteryCooldown
                    } ?? true)

                if preferences.lowBattery && canNotify {
                    alerts.append(.lowBattery(
                        unit: unit,
                        name: name,
                        gauge: transmitter.batteryGauge
                    ))
                    state.batteryLowActive = true
                    state.lastBatteryLowAt = now
                }
            } else {
                state.batteryLowActive = false
                state.lastBatteryLowAt = nil
            }

            if transmitter.isRecording {
                state.wasRecording = true
                state.userStopAt = nil
                state.recordingStopPendingSince = nil
                state.recordingStopWasUserInitiated = false
            } else if state.wasRecording {
                state.wasRecording = false
                state.recordingStopPendingSince = now
                state.recordingStopWasUserInitiated = state.userStopAt.map {
                    now.timeIntervalSince($0) <= timing.userStopSuppression
                } ?? false
            } else if let pendingSince = state.recordingStopPendingSince,
                      now.timeIntervalSince(pendingSince) >= timing.recordingStopDelay {
                state.recordingStopPendingSince = nil

                if !state.recordingStopWasUserInitiated {
                    let canNotify = state.lastRecordingStopAt.map {
                        now.timeIntervalSince($0) >= timing.recordingStopCooldown
                    } ?? true

                    if preferences.recordingStopped && canNotify {
                        alerts.append(.recordingStopped(unit: unit, name: name))
                        state.lastRecordingStopAt = now
                    }
                }
                state.recordingStopWasUserInitiated = false
                state.userStopAt = nil
            }

            units[unit] = state
        }

        return alerts
    }
}
