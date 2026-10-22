import Foundation
import Testing
@testable import DJIMicProtocol

private func bytes(_ hex: String) -> [UInt8] {
    hex.split(separator: " ").compactMap { UInt8($0, radix: 16) }
}

private let status1TX = bytes(
    "55 56 04 67 5a 02 00 00 00 5b 03 03 46 00 03 00 00 00 00 20 00 01 06 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 3e 00 00 00 02 01 00 00 00 1a 38 24 04 89 00 78 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 bc 26"
)

private let identity = bytes(
    "55 80 04 95 5a 02 00 00 00 5b 03 03 70 00 01 00 00 00 00 12 00 11 03 " +
    "02 42 33 4e 58 4e 42 34 30 32 32 52 46 36 53 04 00 00 00 00 06 65 64 " +
    "61 36 33 30 06 00 00 00 00 0e 44 4a 49 20 4d 69 63 20 4d 69 6e 69 20 " +
    "32 01 01 00 00 00 12 00 11 03 02 42 33 4d 54 50 33 4e 30 31 35 5a 58 " +
    "4d 5a 04 01 00 00 00 06 61 66 62 30 36 64 06 01 00 00 00 0e 44 4a 49 " +
    "20 4d 69 63 20 4d 69 6e 69 20 32 c8 c3"
)

private let level = bytes(
    "55 17 04 38 5a 02 00 00 00 5b 03 03 07 00 05 01 00 00 00 01 1e 99 22"
)

private func syntheticAck(sequence: UInt16, value: UInt8) -> [UInt8] {
    var packet = [UInt8](repeating: 0, count: 14)
    packet[0] = 0x55
    packet[1] = 0x0E
    packet[2] = 0x04
    packet[3] = CRC.crc8(Array(packet[0..<3]))
    packet[4] = 0x5A
    packet[5] = 0x02
    packet[6] = UInt8(sequence & 0xFF)
    packet[7] = UInt8(sequence >> 8)
    packet[8] = 0x80
    packet[9] = 0x5B
    packet[10] = 0x01
    packet[11] = value
    let checksum = CRC.crc16(Array(packet[0..<12]))
    packet[12] = UInt8(checksum & 0xFF)
    packet[13] = UInt8(checksum >> 8)
    return packet
}

@Test func commandEncodingMatchesCapturedGainZero() {
    let packet = MicSetting.gain(0).command.encoded(sequence: 0x29A3)
    #expect(packet == bytes("55 16 04 fc 02 5a a3 29 40 5b 01 02 00 00 00 00 39 00 01 00 7a 7a"))
}

@Test func crcValuesAreStable() {
    #expect(CRC.crc8([0x55, 0x16, 0x04]) == 0xFC)
    #expect(CRC.crc16(Array(bytes("55 16 04 fc 02 5a a3 29 40 5b 01 02 00 00 00 00 39 00 01 00")[0..<20])) == 0x7A7A)
}

@Test func parsesStatusPush() throws {
    var parser = DUMLParser()
    let frames = parser.feed(Data(status1TX))
    #expect(frames.count == 1)

    guard case .push(.status(let push)) = try #require(frames.first).content else {
        Issue.record("expected status push")
        return
    }

    #expect(push.receiver?.gain == 6)
    #expect(push.receiver?.monitoringGain == 0)
    #expect(push.receiver?.noiseCancelEnabled == false)
    #expect(push.transmitters[1]?.voiceTone == .bright)
    #expect(push.transmitters[1]?.lowCut == false)
    #expect(push.transmitters[1]?.ledsOff == false)
    #expect(push.transmitters[1]?.autoOff == true)
    #expect(push.transmitters[1]?.clippingControl == true)
    #expect(push.transmitters[1]?.batteryGauge == 1)
    #expect(push.transmitters[1]?.charging == false)
}

@Test func parsesIdentityPush() throws {
    var parser = DUMLParser()
    let frames = parser.feed(Data(identity))
    #expect(frames.count == 1)

    guard case .push(.identity(let push)) = try #require(frames.first).content else {
        Issue.record("expected identity push")
        return
    }

    #expect(push.receiver?.productName == "DJI Mic Mini 2")
    #expect(push.receiver?.firmware == "02.03.17.00")
    #expect(push.transmitters[1]?.productName == "DJI Mic Mini 2")
    #expect(push.transmitters[1]?.firmware == "02.03.17.00")
}

@Test func parsesLevelPush() throws {
    var parser = DUMLParser()
    let frames = parser.feed(Data(level))
    guard case .push(.level(let push)) = try #require(frames.first).content else {
        Issue.record("expected level push")
        return
    }
    #expect(push.levels[1] == 30)
}

@Test func parsesAckAcceptAndReject() throws {
    var parser = DUMLParser()
    let accepted = parser.feed(Data(syntheticAck(sequence: 0x1234, value: 0x00)))
    let rejected = parser.feed(Data(syntheticAck(sequence: 0x1235, value: 0xFF)))

    guard case .ack(let ack) = try #require(accepted.first).content else {
        Issue.record("expected accepted ack")
        return
    }
    #expect(ack.accepted)
    #expect(ack.sequence == 0x1234)

    guard case .ack(let ack) = try #require(rejected.first).content else {
        Issue.record("expected rejected ack")
        return
    }
    #expect(ack.rejected)
}

@Test func parserHandlesSplitAndConcatenatedFrames() {
    var parser = DUMLParser()
    #expect(parser.feed(Data(status1TX.prefix(10))).isEmpty)
    let frames = parser.feed(Data(status1TX.dropFirst(10)) + Data(level))
    #expect(frames.count == 2)
}

@Test func parserRejectsCorruptFrame() {
    var corrupt = status1TX
    corrupt[corrupt.count - 1] ^= 0x01
    var parser = DUMLParser()
    #expect(parser.feed(Data(corrupt)).isEmpty)
}

@Test func settingIdsAreStable() {
    #expect(MicSetting.gain(6).id == .gain)
    #expect(MicSetting.voiceTone(.bright, unit: 2).command.target == .transmitter2)
    #expect(MicSetting.micLED(false, unit: nil).command.value == 2)
    #expect(MicSetting.micLED(true, unit: nil).command.target == .allTransmitters)
    #expect(MicSetting.micLED(true, unit: 1).command.target == .transmitter1)
    #expect(MicSetting.micLED(false, unit: 2).command.target == .transmitter2)
    #expect(MicSetting.micLED(false, unit: 2).command.value == 2)
    #expect(MicSetting.mute(true, unit: 1).id == .mute)
    #expect(MicSetting.recording(true, unit: 2).id == .recording)
}

@Test func resolvesHybridReceiverAndTransmitterProfiles() {
    let receiver = DeviceIdentity(
        productName: "DJI Mic Mini 2",
        serial: "RX",
        firmware: "02.03.17.00",
        addressSuffix: "eda630"
    )
    let transmitter = DeviceIdentity(
        productName: "DJI Mic 2",
        serial: "",
        firmware: "04.05.02.31",
        addressSuffix: "85f8c8"
    )

    let system = DeviceProfileResolver.resolve(
        receiver: receiver,
        transmitters: [1: transmitter]
    )

    #expect(system.receiver.family == .micMini2)
    #expect(system.transmitters[1]?.family == .mic2)
    #expect(system.transmitters[1]?.capabilities.supports(.mute) == true)
    #expect(system.transmitters[1]?.capabilities.supports(.recording) == true)
    #expect(system.receiver.capabilities.supports(.mute) == false)
    #expect(system.receiver.capabilities.supports(.noiseControl) == false)
}

@Test func familyUsesFullProductNamesOnly() {
    func identity(_ name: String) -> DeviceIdentity {
        DeviceIdentity(productName: name, serial: "", firmware: "99.99.99.99", addressSuffix: "")
    }

    #expect(DeviceProfileResolver.family(for: identity("DJI Mic Mini 2")) == .micMini2)
    #expect(DeviceProfileResolver.family(for: identity("DJI Mic 2")) == .mic2)
    #expect(DeviceProfileResolver.family(for: identity("DJI Mic")) == .unknown)
    #expect(DeviceProfileResolver.family(for: nil) == .unknown)
}

@Test func mic2CommandsUseValidatedTargets() throws {
    let system = DeviceProfileResolver.resolve(
        receiver: nil,
        transmitters: [
            1: DeviceIdentity(
                productName: "DJI Mic 2",
                serial: "",
                firmware: "04.05.02.31",
                addressSuffix: "85f8c8"
            ),
        ]
    )

    let mute = try #require(system.command(for: .mute(true, unit: 1)))
    #expect(mute.command == 0x0009)
    #expect(mute.target == .transmitter1)
    #expect(mute.value == 1)

    let recording = try #require(system.command(for: .recording(true, unit: 1)))
    #expect(recording.command == 0x0002)
    #expect(recording.target == .transmitter1)

    let vibration = try #require(system.command(for: .vibration(true)))
    #expect(vibration.command == 0x0004)
    #expect(vibration.target == .allTransmitters)

    let float32 = try #require(system.command(for: .float32Recording(false)))
    #expect(float32.command == 0x000C)

    #expect(system.command(for: .voiceTone(.bright, unit: 1)) == nil)
}

@Test func mic2StatusExtensionsParse() throws {
    var payload = [UInt8](repeating: 0, count: 73)
    payload[3] = 0x03

    let slot = 41
    payload[slot] = 0x02
    payload[slot + 1] = 0x01
    payload[slot + 6] = 0x04   // muted
    payload[slot + 8] = 0x80   // startup auto recording
    payload[slot + 9] = 0x39   // recording + float32 + vibration + low cut
    payload[slot + 11] = 0x20  // rec stop lock
    payload[slot + 14] = 0x70  // 112 -> 11.2h
    payload[slot + 15] = 0x00
    payload[slot + 16] = 0x96  // 150 -> 15.0h
    payload[slot + 17] = 0x00

    let frame = pushFrame(payload)
    var parser = DUMLParser(statusLayout: .mic2)
    let frames = parser.feed(Data(frame))

    #expect(frames.count == 1)
    guard case .push(.status(let push)) = try #require(frames.first).content else {
        Issue.record("expected status push")
        return
    }

    let tx = try #require(push.transmitters[1])
    #expect(tx.isMuted)
    #expect(tx.isRecording)
    #expect(tx.float32Recording)
    #expect(tx.vibrationEnabled)
    #expect(tx.recStopLock)
    #expect(tx.startupAutoRecording)
    #expect(tx.recordingTimeTotal == 11.2)
    #expect(tx.recordingTimeRemaining == 15.0)
}

private func pushFrame(_ payload: [UInt8]) -> [UInt8] {
    let total = payload.count + 13
    var frame: [UInt8] = [
        0x55,
        UInt8(total & 0xFF),
        UInt8((total >> 8) & 0x03),
        0x00,
        0x5A,
        0x02,
        0x00,
        0x00,
        0x00,
        0x5B,
        0x03,
    ]
    frame[3] = CRC.crc8(frame[0..<3])
    frame += payload
    let checksum = CRC.crc16(frame)
    frame += [UInt8(checksum & 0xFF), UInt8((checksum >> 8) & 0xFF)]
    return frame
}
