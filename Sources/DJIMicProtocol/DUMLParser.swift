import Foundation

/// Incremental DUML frame reassembler.
///
/// Bytes may arrive split across reads or several frames may share one read.
/// Invalid candidates are skipped one byte at a time until the next valid
/// start-of-frame, and an incomplete frame is kept for the next `feed`.
public struct DUMLParser: Sendable {
    private var buffer: [UInt8] = []

    public init() {}

    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }

    public mutating func feed(_ data: Data) -> [ParsedFrame] {
        buffer.append(contentsOf: data)

        var frames: [ParsedFrame] = []
        var cursor = 0

        while true {
            guard let frameStart = buffer[cursor...].firstIndex(of: DUML.startOfFrame) else {
                cursor = buffer.count
                break
            }
            cursor = frameStart

            // Wait for the full 4-byte header before validating it.
            guard buffer.count - cursor >= 4 else { break }

            guard CRC.crc8(buffer[cursor..<(cursor + 3)]) == buffer[cursor + 3] else {
                cursor += 1
                continue
            }

            let length = frameLength(at: cursor)
            guard (13...DUML.maxFrameLength).contains(length) else {
                cursor += 1
                continue
            }

            // Wait for the body announced by the header.
            guard buffer.count - cursor >= length else { break }

            guard let frame = validatedFrame(at: cursor, length: length) else {
                cursor += 1
                continue
            }

            frames.append(frame)
            cursor += length
        }

        // Discard consumed bytes in one operation instead of shifting the
        // buffer once per frame.
        buffer.removeFirst(cursor)
        return frames
    }

    private func frameLength(at offset: Int) -> Int {
        let low = Int(buffer[offset + 1])
        let high = Int(buffer[offset + 2]) << 8
        return (low | high) & 0x3FF
    }

    private func validatedFrame(at offset: Int, length: Int) -> ParsedFrame? {
        let end = offset + length
        let expected = UInt16(buffer[end - 2]) | (UInt16(buffer[end - 1]) << 8)
        guard CRC.crc16(buffer[offset..<(end - 2)]) == expected else {
            return nil
        }
        return Self.parse(frame: Array(buffer[offset..<end]))
    }

    public static func parse(frame: [UInt8]) -> ParsedFrame? {
        guard frame.count >= 13, frame[0] == DUML.startOfFrame else { return nil }

        if frame[8] & 0x80 != 0 {
            return parseAcknowledgement(frame)
        }

        let payload = Array(frame[11..<(frame.count - 2)])
        let isHeartbeat = frame[9] == DUML.commandSet && frame[10] == DUML.heartbeatCommand

        guard isHeartbeat else {
            return parseCommandOrUnknown(frame: frame, payload: payload)
        }

        guard let push = parsePush(payload) else { return nil }
        return ParsedFrame(raw: frame, content: .push(push))
    }

    private static func parseAcknowledgement(_ frame: [UInt8]) -> ParsedFrame {
        let sequence = UInt16(frame[6]) | (UInt16(frame[7]) << 8)
        let value = frame.count > 12 ? frame[11] : 0xFF
        return ParsedFrame(raw: frame, content: .ack(AckResult(sequence: sequence, value: value)))
    }

    private static func parseCommandOrUnknown(frame: [UInt8], payload: [UInt8]) -> ParsedFrame {
        let reader = PayloadReader(payload)
        guard let target = reader.uint16(at: 1), let command = reader.uint16(at: 5) else {
            return ParsedFrame(raw: frame, content: .unknown)
        }
        return ParsedFrame(
            raw: frame,
            content: .command(CommandFrame(target: target, command: command, payload: payload))
        )
    }

    // MARK: - Push payloads

    private static func parsePush(_ payload: [UInt8]) -> Push? {
        guard payload.count >= 4 else { return nil }

        switch payload[3] {
        case 0x01:
            return .identity(parseIdentity(payload))
        case 0x03:
            return .status(parseStatus(payload))
        case 0x05:
            return .level(parseLevel(payload))
        default:
            return .unknown(type: payload[3], payload: payload)
        }
    }

    private static func parseIdentity(_ payload: [UInt8]) -> IdentityPush {
        let reader = PayloadReader(payload)
        guard reader.count >= 46 else {
            return IdentityPush(receiver: nil, transmitters: [:])
        }

        return IdentityPush(
            receiver: parseReceiverIdentity(reader),
            transmitters: parseTransmitterIdentities(reader)
        )
    }

    private static func parseReceiverIdentity(_ reader: PayloadReader) -> DeviceIdentity {
        DeviceIdentity(
            productName: reader.lengthPrefixedString(at: 45),
            serial: reader.ascii(at: 13, count: 14),
            firmware: reader.reversedByteString(at: 9, count: 4),
            addressSuffix: reader.ascii(at: 33, count: 6)
        )
    }

    private static func parseTransmitterIdentities(_ reader: PayloadReader) -> [Int: DeviceIdentity] {
        var identities: [Int: DeviceIdentity] = [:]
        var offset = 45 + Int(reader.byte(at: 44) ?? 0)

        while offset + 42 <= reader.count {
            guard reader.byte(at: offset) == 0x01,
                  let unit = reader.byte(at: offset + 1).flatMap(transmitterUnit) else {
                break
            }

            identities[unit] = DeviceIdentity(
                productName: reader.lengthPrefixedString(at: offset + 42),
                serial: reader.ascii(at: offset + 10, count: 14),
                firmware: reader.reversedByteString(at: offset + 6, count: 4),
                addressSuffix: reader.ascii(at: offset + 30, count: 6)
            )

            offset += 42 + Int(reader.byte(at: offset + 41) ?? 0)
        }

        return identities
    }

    private static func parseStatus(_ payload: [UInt8]) -> StatusPush {
        let reader = PayloadReader(payload)
        return StatusPush(
            receiver: parseReceiverState(reader),
            transmitters: parseTransmitterStates(reader)
        )
    }

    private static func parseReceiverState(_ reader: PayloadReader) -> ReceiverState? {
        guard reader.count >= 38,
              let gain = reader.signedByte(at: 11),
              let monitoringGain = reader.signedByte(at: 16) else {
            return nil
        }

        return ReceiverState(
            noiseCancelEnabled: reader.flag(at: 9, mask: 0x20),
            noiseCancelStrong: reader.flag(at: 9, mask: 0x08),
            gain: gain,
            monitoringGain: monitoringGain,
            stereo: reader.flag(at: 10, mask: 0x04),
            safetyTrack: reader.flag(at: 37, mask: 0x40),
            clippingControl: reader.flag(at: 37, mask: 0x10),
            autoOff: reader.flag(at: 10, mask: 0x01),
            flags9: reader.byte(at: 9) ?? 0,
            flags10: reader.byte(at: 10) ?? 0,
            flags37: reader.byte(at: 37) ?? 0
        )
    }

    private static func parseTransmitterStates(_ reader: PayloadReader) -> [Int: TransmitterState] {
        var states: [Int: TransmitterState] = [:]
        var offset = 41

        while offset + 31 < reader.count {
            if let unit = reader.byte(at: offset + 1).flatMap(transmitterUnit),
               reader.byte(at: offset) == 0x02 {
                states[unit] = parseTransmitterState(reader, at: offset, unit: unit)
            }
            offset += 32
        }

        return states
    }

    private static func parseTransmitterState(
        _ reader: PayloadReader,
        at offset: Int,
        unit: Int
    ) -> TransmitterState {
        TransmitterState(
            unit: unit,
            noiseCancelEnabled: reader.flag(at: offset + 7, mask: 0x01),
            noiseCancelStrong: reader.flag(at: offset + 6, mask: 0x20),
            noiseCancelViaButton: reader.flag(at: offset + 6, mask: 0x80),
            lowCut: reader.flag(at: offset + 9, mask: 0x20),
            ledsOff: reader.flag(at: offset + 6, mask: 0x02),
            autoOff: reader.flag(at: offset + 6, mask: 0x10),
            autoOffTimerActive: reader.flag(at: offset + 6, mask: 0x08),
            clippingControl: reader.flag(at: offset + 8, mask: 0x04),
            voiceTone: parseVoiceTone(reader.byte(at: offset + 9) ?? 0),
            charging: reader.flag(at: offset + 7, mask: 0x02),
            batteryGauge: Int((reader.byte(at: offset + 7) ?? 0) >> 2 & 0x07)
        )
    }

    private static func parseVoiceTone(_ flags: UInt8) -> VoiceTone {
        switch flags & 0xC0 {
        case 0x40: .rich
        case 0x80: .bright
        default: .regular
        }
    }

    private static func parseLevel(_ payload: [UInt8]) -> LevelPush {
        let reader = PayloadReader(payload)
        var levels: [Int: Int] = [:]
        var offset = 3

        while offset + 6 < reader.count {
            if reader.byte(at: offset) == 0x05,
               let unit = reader.byte(at: offset + 1).flatMap(transmitterUnit),
               let level = reader.byte(at: offset + 6) {
                levels[unit] = Int(level)
            }
            offset += 7
        }

        return LevelPush(levels: levels)
    }

    private static func transmitterUnit(_ byte: UInt8) -> Int? {
        switch byte {
        case 0x01: 1
        case 0x02: 2
        case 0x04: 3
        case 0x08: 4
        default: nil
        }
    }
}
