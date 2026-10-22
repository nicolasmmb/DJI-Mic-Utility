import DJIMicProtocol
import DJIMicSession
import Foundation
import Testing
@testable import DJIMicUI

private final class ControllableMicClient: MicClient {
    let snapshots: AsyncStream<DeviceSnapshot>
    let events: AsyncStream<SessionEvent>

    private let continuation: AsyncStream<DeviceSnapshot>.Continuation
    var sendError: Error?
    private(set) var sent: [MicSetting] = []

    init() {
        var continuation: AsyncStream<DeviceSnapshot>.Continuation!
        snapshots = AsyncStream { continuation = $0 }
        self.continuation = continuation
        events = AsyncStream { _ in }
    }

    func start() {}
    func stop() {}
    func reconnect() {}

    func send(_ setting: MicSetting) async throws {
        sent.append(setting)
        if let sendError {
            throw sendError
        }
    }

    func push(_ snapshot: DeviceSnapshot) {
        continuation.yield(snapshot)
    }
}

private func connectedSnapshot(stereo: Bool, updatedAt: Date = Date()) -> DeviceSnapshot {
    DeviceSnapshot(
        connection: .connected,
        receiverIdentity: DeviceIdentity(
            productName: "DJI Mic Mini 2",
            serial: "TEST",
            firmware: "02.03.17.00",
            addressSuffix: "000000"
        ),
        receiver: ReceiverState(
            noiseCancelEnabled: false,
            noiseCancelStrong: false,
            gain: 0,
            monitoringGain: 0,
            stereo: stereo,
            safetyTrack: false,
            clippingControl: false,
            autoOff: false,
            flags9: 0,
            flags10: 0,
            flags37: 0
        ),
        transmitters: [1: TransmitterState(unit: 1)],
        updatedAt: updatedAt
    )
}

@MainActor
private func waitUntil(
    timeout: TimeInterval = 10,
    _ condition: () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
}

@Test @MainActor func staleStatusPushDoesNotRevertOptimisticValue() async throws {
    let client = ControllableMicClient()
    let model = AppModel(session: client, initialSnapshot: connectedSnapshot(stereo: false))

    model.send(.stereo(true))
    #expect(model.snapshot.receiver?.stereo == true)

    // A push generated before the receiver applied the command still reports
    // the old value. It must not undo the optimistic selection.
    let stale = connectedSnapshot(stereo: false)
    client.push(stale)
    try await waitUntil { model.snapshot.updatedAt == stale.updatedAt }
    #expect(model.snapshot.receiver?.stereo == true)

    // Once the device confirms, the overlay is released and the real value
    // wins.
    let confirmed = connectedSnapshot(stereo: true)
    client.push(confirmed)
    try await waitUntil { model.snapshot.updatedAt == confirmed.updatedAt }
    #expect(model.snapshot.receiver?.stereo == true)
}

@Test @MainActor func rejectedCommandRevertsToLastDeviceState() async throws {
    let client = ControllableMicClient()
    client.sendError = MicSessionError.rejected
    let model = AppModel(session: client, initialSnapshot: connectedSnapshot(stereo: false))

    model.send(.stereo(true))
    #expect(model.snapshot.receiver?.stereo == true)

    try await waitUntil {
        model.errorMessage != nil && model.snapshot.receiver?.stereo == false
    }
    #expect(model.snapshot.receiver?.stereo == false)
}
