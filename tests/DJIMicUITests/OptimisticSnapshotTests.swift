import DJIMicProtocol
import Foundation
import Testing
@testable import DJIMicUI

private func makeSnapshot() -> DeviceSnapshot {
    DeviceSnapshot(
        connection: .connected,
        receiver: ReceiverState(
            noiseCancelEnabled: false,
            noiseCancelStrong: false,
            gain: 0,
            monitoringGain: 0,
            stereo: false,
            safetyTrack: false,
            clippingControl: false,
            autoOff: false,
            flags9: 0,
            flags10: 0,
            flags37: 0
        ),
        transmitters: [
            1: TransmitterState(unit: 1, lowCut: false, ledsOff: false, autoOff: false),
            2: TransmitterState(unit: 2, lowCut: false, ledsOff: true, autoOff: false),
        ]
    )
}

@Test func optimisticMicLEDWithoutUnitUpdatesEveryTransmitter() {
    var snapshot = makeSnapshot()

    snapshot.applyOptimistic(.micLED(true, unit: nil))

    #expect(snapshot.transmitters.values.allSatisfy { !$0.ledsOff })
}

@Test func optimisticMicLEDWithUnitOnlyUpdatesThatTransmitter() {
    var snapshot = makeSnapshot()

    snapshot.applyOptimistic(.micLED(true, unit: 2))

    #expect(snapshot.transmitters[1]?.ledsOff == false)
    #expect(snapshot.transmitters[2]?.ledsOff == false)
}

@Test func optimisticGlobalSettingsReachReceiverAndTransmitters() {
    var snapshot = makeSnapshot()

    snapshot.applyOptimistic(.lowCut(true))
    snapshot.applyOptimistic(.clippingControl(true))
    snapshot.applyOptimistic(.autoOffTX(true))

    #expect(snapshot.transmitters.values.allSatisfy { $0.lowCut })
    #expect(snapshot.transmitters.values.allSatisfy { $0.clippingControl })
    #expect(snapshot.transmitters.values.allSatisfy { $0.autoOff })
    #expect(snapshot.receiver?.clippingControl == true)
}

@Test func optimisticPerUnitSettingDoesNotLeakToOtherTransmitter() {
    var snapshot = makeSnapshot()

    snapshot.applyOptimistic(.voiceTone(.bright, unit: 2))

    #expect(snapshot.transmitters[1]?.voiceTone == .regular)
    #expect(snapshot.transmitters[2]?.voiceTone == .bright)
}

@Test func snapshotReflectsOnlyConfirmedValues() {
    var snapshot = makeSnapshot()

    snapshot.applyOptimistic(.stereo(true))
    snapshot.applyOptimistic(.lowCut(true))

    #expect(snapshot.reflects(.stereo(true)))
    #expect(!snapshot.reflects(.stereo(false)))
    #expect(snapshot.reflects(.lowCut(true)))
    #expect(!snapshot.reflects(.lowCut(false)))
}

@Test func snapshotReflectsPerUnitMicLED() {
    var snapshot = makeSnapshot()

    snapshot.applyOptimistic(.micLED(false, unit: 2))

    #expect(snapshot.reflects(.micLED(false, unit: 2)))
    #expect(!snapshot.reflects(.micLED(false, unit: nil)))
    #expect(snapshot.reflects(.micLED(true, unit: 1)))
}
