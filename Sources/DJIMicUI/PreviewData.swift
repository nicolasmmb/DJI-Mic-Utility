import DJIMicProtocol
import DJIMicSession
import Foundation

#if DEBUG
final class StaticMicClient: MicClient, @unchecked Sendable {
    let snapshots: AsyncStream<DeviceSnapshot>
    let events: AsyncStream<SessionEvent>

    private let continuation: AsyncStream<DeviceSnapshot>.Continuation
    private let snapshot: DeviceSnapshot

    init(snapshot: DeviceSnapshot) {
        self.snapshot = snapshot
        var continuation: AsyncStream<DeviceSnapshot>.Continuation!
        self.snapshots = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        self.continuation = continuation
        self.events = AsyncStream { _ in }
    }

    func start() {
        continuation.yield(snapshot)
    }

    func stop() {}
    func reconnect() {}
    func send(_ setting: MicSetting) async throws {}
}

extension DeviceSnapshot {
    static var preview: DeviceSnapshot {
        DeviceSnapshot(
            connection: .connected,
            receiverIdentity: DeviceIdentity(
                productName: "DJI Mic Mini 2",
                serial: "B3NXNB4022RF6S",
                firmware: "02.03.17.00",
                addressSuffix: "eda630"
            ),
            transmitterIdentities: [
                1: DeviceIdentity(
                    productName: "DJI Mic 2",
                    serial: "",
                    firmware: "04.05.02.31",
                    addressSuffix: "85f8c8"
                ),
            ],
            receiver: ReceiverState(
                noiseCancelEnabled: true,
                noiseCancelStrong: true,
                gain: 0,
                monitoringGain: 0,
                stereo: false,
                safetyTrack: false,
                clippingControl: true,
                autoOff: true,
                flags9: 0x28,
                flags10: 0x01,
                flags37: 0x3E
            ),
            transmitters: [
                1: TransmitterState(
                    unit: 1,
                    noiseCancelEnabled: true,
                    noiseCancelStrong: true,
                    lowCut: true,
                    ledsOff: false,
                    autoOff: true,
                    clippingControl: true,
                    voiceTone: .bright,
                    batteryGauge: 1,
                    inputLevel: 42,
                    float32Recording: true,
                    recordingTimeTotal: 11.2,
                    recordingTimeRemaining: 11.2
                ),
            ]
        )
    }
}

extension AppModel {
    static var preview: AppModel {
        let snapshot = DeviceSnapshot.preview
        return AppModel(session: StaticMicClient(snapshot: snapshot), initialSnapshot: snapshot)
    }
}
#endif
