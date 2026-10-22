import DJIMicProtocol
import DJIMicSession
import DJIMicUI
import Foundation
import Testing

private final class RecordingMicClient: MicClient, @unchecked Sendable {
    let snapshots: AsyncStream<DeviceSnapshot>
    let events: AsyncStream<SessionEvent>

    private let snapshotContinuation: AsyncStream<DeviceSnapshot>.Continuation
    private let lock = NSLock()
    private var recorded: [MicSetting] = []
    private let initial: DeviceSnapshot

    init(snapshot: DeviceSnapshot) {
        initial = snapshot
        var continuation: AsyncStream<DeviceSnapshot>.Continuation!
        snapshots = AsyncStream { continuation = $0 }
        snapshotContinuation = continuation
        events = AsyncStream { _ in }
    }

    var sent: [MicSetting] {
        lock.withLock { recorded }
    }

    func start() {
        snapshotContinuation.yield(initial)
    }

    func stop() {}
    func reconnect() {}

    func send(_ setting: MicSetting) async throws {
        lock.withLock { recorded.append(setting) }
    }
}

private func makeSnapshot(ledsOff: Bool, units: [Int] = [1]) -> DeviceSnapshot {
    var transmitters: [Int: TransmitterState] = [:]
    for unit in units {
        transmitters[unit] = TransmitterState(unit: unit, ledsOff: ledsOff)
    }
    return DeviceSnapshot(connection: .connected, transmitters: transmitters)
}

@Test @MainActor func findRestoresLEDsThatWereOn() async {
    let snapshot = makeSnapshot(ledsOff: false)
    let client = RecordingMicClient(snapshot: snapshot)
    let model = AppModel(session: client, initialSnapshot: snapshot)
    defer { model.stop() }

    let task = model.findTransmitter(unit: 1, blinks: 2, interval: .milliseconds(1))
    await task?.value

    let sent = client.sent
    #expect(sent.count == 5)
    #expect(sent.first == .micLED(true, unit: 1))
    #expect(sent.last == .micLED(true, unit: 1))
    #expect(sent.allSatisfy { $0.command.target == .transmitter1 })
    #expect(model.findingUnit == nil)
}

@Test @MainActor func findRestoresLEDsThatWereOff() async {
    let snapshot = makeSnapshot(ledsOff: true)
    let client = RecordingMicClient(snapshot: snapshot)
    let model = AppModel(session: client, initialSnapshot: snapshot)
    defer { model.stop() }

    let task = model.findTransmitter(unit: 1, blinks: 2, interval: .milliseconds(1))
    await task?.value

    let sent = client.sent
    #expect(sent.count == 5)
    #expect(sent.first == .micLED(true, unit: 1))
    #expect(sent.last == .micLED(false, unit: 1))
    #expect(model.findingUnit == nil)
}

@Test @MainActor func findTargetsTheRequestedUnit() async {
    let snapshot = makeSnapshot(ledsOff: false, units: [1, 2])
    let client = RecordingMicClient(snapshot: snapshot)
    let model = AppModel(session: client, initialSnapshot: snapshot)
    defer { model.stop() }

    let task = model.findTransmitter(unit: 2, blinks: 1, interval: .milliseconds(1))
    await task?.value

    #expect(!client.sent.isEmpty)
    #expect(client.sent.allSatisfy { $0.command.target == .transmitter2 })
}

@Test @MainActor func findIsIgnoredWhileDisconnected() async {
    let snapshot = DeviceSnapshot(
        connection: .disconnected,
        transmitters: [1: TransmitterState(unit: 1)]
    )
    let client = RecordingMicClient(snapshot: snapshot)
    let model = AppModel(session: client, initialSnapshot: snapshot)
    defer { model.stop() }

    #expect(model.findTransmitter(unit: 1) == nil)
    #expect(client.sent.isEmpty)
}
