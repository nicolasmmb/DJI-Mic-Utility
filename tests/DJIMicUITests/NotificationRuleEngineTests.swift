import DJIMicProtocol
import Foundation
import Testing
@testable import DJIMicUI

private let t0 = Date(timeIntervalSince1970: 1_000)

private let fastTiming = NotificationRuleEngine.Timing(
    receiverConnectDelay: 0.5,
    transmitterConnectDelay: 0.5,
    disconnectDelay: 0.5,
    recordingStopDelay: 0.5,
    linkLostDelay: 0.5,
    connectGroupWindow: 1,
    batteryCooldown: 10,
    disconnectCooldown: 10,
    recordingStopCooldown: 10,
    linkLostCooldown: 10,
    userStopSuppression: 2
)

private func snapshot(
    connected: Bool = true,
    battery: Int = 3,
    charging: Bool = false,
    recording: Bool = false,
    includeTransmitter: Bool = true
) -> DeviceSnapshot {
    let tx = TransmitterState(
        unit: 1,
        charging: charging,
        batteryGauge: battery,
        isRecording: recording
    )
    return DeviceSnapshot(
        connection: connected ? .connected : .reconnecting,
        receiverIdentity: DeviceIdentity(
            productName: "DJI Mic Mini 2",
            serial: "RX",
            firmware: "02.03.17.00",
            addressSuffix: "eda630"
        ),
        transmitterIdentities: includeTransmitter
            ? [1: DeviceIdentity(
                productName: "DJI Mic 2",
                serial: "",
                firmware: "04.05.02.31",
                addressSuffix: "85f8c8"
            )]
            : [:],
        receiver: ReceiverState(
            noiseCancelEnabled: false,
            noiseCancelStrong: false,
            gain: 0,
            monitoringGain: 0,
            stereo: false,
            safetyTrack: false,
            clippingControl: false,
            autoOff: true,
            flags9: 0,
            flags10: 1,
            flags37: 0
        ),
        transmitters: includeTransmitter ? [1: tx] : [:],
        updatedAt: t0
    )
}

private func hasLowBattery(_ alerts: [MicAlert]) -> Bool {
    alerts.contains {
        if case .lowBattery = $0 { return true }
        return false
    }
}

@Test func lowBatteryAlertsOnceAndRearmsAfterRecovery() {
    let engine = NotificationRuleEngine(timing: fastTiming)
    let prefs = NotificationPreferences()

    _ = engine.evaluate(snapshot: snapshot(battery: 3), preferences: prefs, now: t0)

    let first = engine.evaluate(
        snapshot: snapshot(battery: 6),
        preferences: prefs,
        now: t0.addingTimeInterval(1)
    )
    #expect(hasLowBattery(first))

    let repeated = engine.evaluate(
        snapshot: snapshot(battery: 6),
        preferences: prefs,
        now: t0.addingTimeInterval(2)
    )
    #expect(!hasLowBattery(repeated))

    _ = engine.evaluate(
        snapshot: snapshot(battery: 2),
        preferences: prefs,
        now: t0.addingTimeInterval(3)
    )
    let recoveredAndLowAgain = engine.evaluate(
        snapshot: snapshot(battery: 6),
        preferences: prefs,
        now: t0.addingTimeInterval(4)
    )
    #expect(hasLowBattery(recoveredAndLowAgain))
}

@Test func disabledLowBatteryPreferenceSuppressesAlert() {
    let engine = NotificationRuleEngine(timing: fastTiming)
    var prefs = NotificationPreferences()
    prefs.lowBattery = false

    _ = engine.evaluate(snapshot: snapshot(battery: 3), preferences: prefs, now: t0)
    let alerts = engine.evaluate(
        snapshot: snapshot(battery: 6),
        preferences: prefs,
        now: t0.addingTimeInterval(1)
    )
    #expect(!hasLowBattery(alerts))
}

@Test func transmitterDisconnectIsDebouncedAndCoalesced() {
    let engine = NotificationRuleEngine(timing: fastTiming)
    let prefs = NotificationPreferences()

    _ = engine.evaluate(snapshot: snapshot(), preferences: prefs, now: t0)

    let early = engine.evaluate(
        snapshot: snapshot(includeTransmitter: false),
        preferences: prefs,
        now: t0.addingTimeInterval(0.2)
    )
    #expect(early.isEmpty)

    let disconnected = engine.evaluate(
        snapshot: snapshot(includeTransmitter: false),
        preferences: prefs,
        now: t0.addingTimeInterval(0.8)
    )
    #expect(disconnected.contains {
        if case .transmitterDisconnected(unit: 1, _) = $0 { return true }
        return false
    })

    let repeated = engine.evaluate(
        snapshot: snapshot(includeTransmitter: false),
        preferences: prefs,
        now: t0.addingTimeInterval(1.5)
    )
    #expect(!repeated.contains {
        if case .transmitterDisconnected = $0 { return true }
        return false
    })
}

@Test func recordingStopAlertsUnlessUserStoppedIt() {
    let engine = NotificationRuleEngine(timing: fastTiming)
    let prefs = NotificationPreferences()

    _ = engine.evaluate(snapshot: snapshot(recording: true), preferences: prefs, now: t0)

    let waiting = engine.evaluate(
        snapshot: snapshot(recording: false),
        preferences: prefs,
        now: t0.addingTimeInterval(1)
    )
    #expect(!waiting.contains {
        if case .recordingStopped = $0 { return true }
        return false
    })

    let alerts = engine.evaluate(
        snapshot: snapshot(recording: false),
        preferences: prefs,
        now: t0.addingTimeInterval(1.6)
    )
    #expect(alerts.contains {
        if case .recordingStopped(unit: 1, _) = $0 { return true }
        return false
    })

    let engine2 = NotificationRuleEngine(timing: fastTiming)
    _ = engine2.evaluate(snapshot: snapshot(recording: true), preferences: prefs, now: t0)
    engine2.noteUserStoppedRecording(unit: 1, at: t0.addingTimeInterval(1))
    _ = engine2.evaluate(
        snapshot: snapshot(recording: false),
        preferences: prefs,
        now: t0.addingTimeInterval(1.2)
    )
    let intentional = engine2.evaluate(
        snapshot: snapshot(recording: false),
        preferences: prefs,
        now: t0.addingTimeInterval(1.8)
    )
    #expect(!intentional.contains {
        if case .recordingStopped = $0 { return true }
        return false
    })
}

@Test func recordingRestartDuringDebounceSuppressesAlert() {
    let engine = NotificationRuleEngine(timing: fastTiming)
    let prefs = NotificationPreferences()

    _ = engine.evaluate(snapshot: snapshot(recording: true), preferences: prefs, now: t0)
    _ = engine.evaluate(
        snapshot: snapshot(recording: false),
        preferences: prefs,
        now: t0.addingTimeInterval(1)
    )
    _ = engine.evaluate(
        snapshot: snapshot(recording: true),
        preferences: prefs,
        now: t0.addingTimeInterval(1.2)
    )
    let alerts = engine.evaluate(
        snapshot: snapshot(recording: true),
        preferences: prefs,
        now: t0.addingTimeInterval(3)
    )
    #expect(!alerts.contains {
        if case .recordingStopped = $0 { return true }
        return false
    })
}

@Test func linkLostSuppressesTransmitterAlerts() {
    let engine = NotificationRuleEngine(timing: fastTiming)
    let prefs = NotificationPreferences()

    _ = engine.evaluate(snapshot: snapshot(), preferences: prefs, now: t0)

    _ = engine.evaluate(
        snapshot: snapshot(connected: false, includeTransmitter: false),
        preferences: prefs,
        now: t0.addingTimeInterval(1)
    )
    let alerts = engine.evaluate(
        snapshot: snapshot(connected: false, includeTransmitter: false),
        preferences: prefs,
        now: t0.addingTimeInterval(2)
    )

    #expect(alerts.contains { if case .linkLost = $0 { return true }; return false })
    #expect(!alerts.contains {
        if case .transmitterDisconnected = $0 { return true }
        return false
    })
}

@Test func connectAlertsOnlyOnTransitionAndAfterDebounce() {
    let engine = NotificationRuleEngine(timing: fastTiming)
    let prefs = NotificationPreferences()

    // Prime disconnected.
    _ = engine.evaluate(
        snapshot: snapshot(connected: false, includeTransmitter: false),
        preferences: prefs,
        now: t0
    )

    _ = engine.evaluate(snapshot: snapshot(), preferences: prefs, now: t0.addingTimeInterval(1))
    let late = engine.evaluate(
        snapshot: snapshot(),
        preferences: prefs,
        now: t0.addingTimeInterval(1.6)
    )
    #expect(late.contains { if case .receiverConnected = $0 { return true }; return false })

    let grouped = engine.evaluate(
        snapshot: snapshot(),
        preferences: prefs,
        now: t0.addingTimeInterval(2)
    )
    #expect(!grouped.contains { if case .transmitterConnected = $0 { return true }; return false })

    let transmitter = engine.evaluate(
        snapshot: snapshot(),
        preferences: prefs,
        now: t0.addingTimeInterval(3.2)
    )
    #expect(transmitter.contains { if case .transmitterConnected = $0 { return true }; return false })
}

@Test func connectedAtLaunchIsSilentByDefault() {
    let engine = NotificationRuleEngine(timing: fastTiming)
    let prefs = NotificationPreferences()

    _ = engine.evaluate(snapshot: snapshot(), preferences: prefs, now: t0)
    let alerts = engine.evaluate(
        snapshot: snapshot(),
        preferences: prefs,
        now: t0.addingTimeInterval(2)
    )

    #expect(!alerts.contains { if case .receiverConnected = $0 { return true }; return false })
    #expect(!alerts.contains { if case .transmitterConnected = $0 { return true }; return false })
}

@Test func connectedAtLaunchCanBeAnnouncedWhenRequested() {
    let engine = NotificationRuleEngine(timing: fastTiming)
    var prefs = NotificationPreferences()
    prefs.notifyOnLaunchWhenConnected = true

    _ = engine.evaluate(snapshot: snapshot(), preferences: prefs, now: t0)
    let alerts = engine.evaluate(
        snapshot: snapshot(),
        preferences: prefs,
        now: t0.addingTimeInterval(0.6)
    )

    #expect(alerts.contains { if case .receiverConnected = $0 { return true }; return false })
}

@Test func chargingPostponesLowBatteryAlert() {
    let engine = NotificationRuleEngine(timing: fastTiming)
    let prefs = NotificationPreferences()

    _ = engine.evaluate(
        snapshot: snapshot(battery: 6, charging: true),
        preferences: prefs,
        now: t0
    )
    let charging = engine.evaluate(
        snapshot: snapshot(battery: 6, charging: true),
        preferences: prefs,
        now: t0.addingTimeInterval(1)
    )
    #expect(!hasLowBattery(charging))

    let unplugged = engine.evaluate(
        snapshot: snapshot(battery: 6, charging: false),
        preferences: prefs,
        now: t0.addingTimeInterval(2)
    )
    #expect(hasLowBattery(unplugged))
}

@Test func masterSwitchSuppressesAlerts() {
    let engine = NotificationRuleEngine(timing: fastTiming)
    var prefs = NotificationPreferences()
    prefs.enabled = false

    _ = engine.evaluate(snapshot: snapshot(battery: 3), preferences: prefs, now: t0)
    let alerts = engine.evaluate(
        snapshot: snapshot(battery: 6),
        preferences: prefs,
        now: t0.addingTimeInterval(1)
    )

    #expect(alerts.isEmpty)
}

@Test func masterSwitchBlocksEveryAlertKind() {
    let prefs = NotificationPreferences(enabled: false)
    let alerts: [MicAlert] = [
        .receiverConnected(name: nil),
        .transmitterConnected(unit: 1, name: nil, batteryGauge: 1, charging: false),
        .lowBattery(unit: 1, name: nil, gauge: 6),
        .transmitterDisconnected(unit: 1, name: nil),
        .recordingStopped(unit: 1, name: nil),
        .linkLost(receiverName: nil),
    ]

    for alert in alerts {
        #expect(!prefs.allows(alert))
    }
}
