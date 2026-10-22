import Foundation

public enum DUML {
    public static let startOfFrame: UInt8 = 0x55
    public static let protocolVersion: UInt8 = 0x04
    public static let commandLength = 22
    public static let commandSet: UInt8 = 0x5B
    public static let heartbeatCommand: UInt8 = 0x03
    public static let maxFrameLength = 2048
}

public enum CommandTarget: UInt16, Sendable, Equatable {
    case receiver = 0x0000
    case transmitter1 = 0x0001
    case transmitter2 = 0x0002
    case allTransmitters = 0xFFFF
}

public struct MicCommand: Sendable, Equatable {
    public var target: CommandTarget
    public var command: UInt16
    public var value: UInt8

    public init(target: CommandTarget, command: UInt16, value: UInt8) {
        self.target = target
        self.command = command
        self.value = value
    }

    public func encoded(sequence: UInt16) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: DUML.commandLength)
        packet[0] = DUML.startOfFrame
        packet[1] = UInt8(DUML.commandLength)
        packet[2] = DUML.protocolVersion
        packet[3] = CRC.crc8(Array(packet[0..<3]))
        packet[4] = 0x02
        packet[5] = 0x5A
        packet[6] = UInt8(sequence & 0xFF)
        packet[7] = UInt8((sequence >> 8) & 0xFF)
        packet[8] = 0x40
        packet[9] = DUML.commandSet
        packet[10] = 0x01
        packet[11] = 0x02
        packet[12] = UInt8(target.rawValue & 0xFF)
        packet[13] = UInt8((target.rawValue >> 8) & 0xFF)
        packet[16] = UInt8(command & 0xFF)
        packet[17] = UInt8((command >> 8) & 0xFF)
        packet[18] = 0x01
        packet[19] = value
        let checksum = CRC.crc16(Array(packet[0..<20]))
        packet[20] = UInt8(checksum & 0xFF)
        packet[21] = UInt8((checksum >> 8) & 0xFF)
        return packet
    }
}

public struct CommandFrame: Equatable, Sendable {
    public var target: UInt16
    public var command: UInt16
    public var payload: [UInt8]
}

public struct AckResult: Equatable, Sendable {
    public var sequence: UInt16
    public var value: UInt8

    public var accepted: Bool { value == 0x00 }
    public var rejected: Bool { value == 0xFF }
}

public enum Push: Equatable, Sendable {
    case identity(IdentityPush)
    case status(StatusPush)
    case level(LevelPush)
    case unknown(type: UInt8, payload: [UInt8])
}

public struct IdentityPush: Equatable, Sendable {
    public var receiver: DeviceIdentity?
    public var transmitters: [Int: DeviceIdentity]
}

public struct StatusPush: Equatable, Sendable {
    public var receiver: ReceiverState?
    public var transmitters: [Int: TransmitterState]
}

public struct LevelPush: Equatable, Sendable {
    public var levels: [Int: Int]
}

public enum FrameContent: Equatable, Sendable {
    case ack(AckResult)
    case push(Push)
    case command(CommandFrame)
    case unknown
}

public struct ParsedFrame: Equatable, Sendable {
    public var raw: [UInt8]
    public var content: FrameContent

    public var isAcknowledgement: Bool {
        if case .ack = content { return true }
        return false
    }
}

public struct DUMLParser: Sendable {
    private var buffer: [UInt8] = []

    public init() {}

    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }

    public mutating func feed(_ data: Data) -> [ParsedFrame] {
        buffer.append(contentsOf: data)
        var frames: [ParsedFrame] = []

        while true {
            guard let start = buffer.firstIndex(of: DUML.startOfFrame) else {
                buffer.removeAll(keepingCapacity: true)
                break
            }

            if start > 0 {
                buffer.removeFirst(start)
            }

            guard buffer.count >= 4 else { break }

            guard CRC.crc8(Array(buffer[0..<3])) == buffer[3] else {
                buffer.removeFirst()
                continue
            }

            let length = Int(UInt16(buffer[1]) | (UInt16(buffer[2]) << 8)) & 0x3FF
            guard length >= 13, length <= DUML.maxFrameLength else {
                buffer.removeFirst()
                continue
            }

            guard buffer.count >= length else { break }

            let frame = Array(buffer[0..<length])
            let expected = UInt16(frame[length - 2]) | (UInt16(frame[length - 1]) << 8)
            guard CRC.crc16(Array(frame[0..<(length - 2)])) == expected else {
                buffer.removeFirst()
                continue
            }

            buffer.removeFirst(length)
            if let parsed = Self.parse(frame: frame) {
                frames.append(parsed)
            }
        }

        return frames
    }

    public static func parse(frame: [UInt8]) -> ParsedFrame? {
        guard frame.count >= 13, frame[0] == DUML.startOfFrame else { return nil }

        let flags = frame[8]
        if flags & 0x80 != 0 {
            let sequence = UInt16(frame[6]) | (UInt16(frame[7]) << 8)
            let value = frame.count > 12 ? frame[11] : 0xFF
            return ParsedFrame(raw: frame, content: .ack(AckResult(sequence: sequence, value: value)))
        }

        let commandSet = frame[9]
        let commandID = frame[10]
        let payload = Array(frame[11..<(frame.count - 2)])

        if commandSet == DUML.commandSet && commandID == DUML.heartbeatCommand {
            guard let push = parsePush(payload) else { return nil }
            return ParsedFrame(raw: frame, content: .push(push))
        }

        if payload.count >= 7 {
            let target = UInt16(payload[1]) | (UInt16(payload[2]) << 8)
            let command = UInt16(payload[5]) | (UInt16(payload[6]) << 8)
            return ParsedFrame(
                raw: frame,
                content: .command(CommandFrame(target: target, command: command, payload: payload))
            )
        }

        return ParsedFrame(raw: frame, content: .unknown)
    }

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
        var result = IdentityPush(receiver: nil, transmitters: [:])

        if payload.count >= 46 {
            result.receiver = DeviceIdentity(
                productName: variableString(payload, at: 45),
                serial: ascii(payload, at: 13, count: 14),
                firmware: firmware(payload, at: 9),
                addressSuffix: ascii(payload, at: 33, count: 6)
            )

            var offset = 45 + Int(payload[44])
            while offset + 42 <= payload.count {
                guard payload[offset] == 0x01,
                      let unit = transmitterUnit(payload[offset + 1]) else {
                    break
                }

                result.transmitters[unit] = DeviceIdentity(
                    productName: variableString(payload, at: offset + 42),
                    serial: ascii(payload, at: offset + 10, count: 14),
                    firmware: firmware(payload, at: offset + 6),
                    addressSuffix: ascii(payload, at: offset + 30, count: 6)
                )

                offset += 42 + Int(payload[offset + 41])
            }
        }

        return result
    }

    private static func parseStatus(_ payload: [UInt8]) -> StatusPush {
        var result = StatusPush(receiver: nil, transmitters: [:])

        if payload.count >= 38 {
            result.receiver = ReceiverState(
                noiseCancelEnabled: payload[9] & 0x20 != 0,
                noiseCancelStrong: payload[9] & 0x08 != 0,
                gain: Int(Int8(bitPattern: payload[11])),
                monitoringGain: Int(Int8(bitPattern: payload[16])),
                stereo: payload[10] & 0x04 != 0,
                safetyTrack: payload[37] & 0x40 != 0,
                clippingControl: payload[37] & 0x10 != 0,
                autoOff: payload[10] & 0x01 != 0,
                flags9: payload[9],
                flags10: payload[10],
                flags37: payload[37]
            )
        }

        var offset = 41
        while offset + 31 < payload.count {
            if payload[offset] == 0x02, let unit = transmitterUnit(payload[offset + 1]) {
                let toneBits = payload[offset + 9] & 0xC0
                let tone: VoiceTone = toneBits == 0x40 ? .rich : (toneBits == 0x80 ? .bright : .regular)
                let gauge = Int((payload[offset + 7] >> 2) & 0x07)

                result.transmitters[unit] = TransmitterState(
                    unit: unit,
                    noiseCancelEnabled: payload[offset + 7] & 0x01 != 0,
                    noiseCancelStrong: payload[offset + 6] & 0x20 != 0,
                    noiseCancelViaButton: payload[offset + 6] & 0x80 != 0,
                    lowCut: payload[offset + 9] & 0x20 != 0,
                    ledsOff: payload[offset + 6] & 0x02 != 0,
                    autoOff: payload[offset + 6] & 0x10 != 0,
                    autoOffTimerActive: payload[offset + 6] & 0x08 != 0,
                    clippingControl: payload[offset + 8] & 0x04 != 0,
                    voiceTone: tone,
                    charging: payload[offset + 7] & 0x02 != 0,
                    batteryGauge: gauge
                )
            }
            offset += 32
        }

        return result
    }

    private static func parseLevel(_ payload: [UInt8]) -> LevelPush {
        var result = LevelPush(levels: [:])
        var offset = 3
        while offset + 6 < payload.count {
            if payload[offset] == 0x05, let unit = transmitterUnit(payload[offset + 1]) {
                result.levels[unit] = Int(payload[offset + 6])
            }
            offset += 7
        }
        return result
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

    private static func ascii(_ payload: [UInt8], at offset: Int, count: Int) -> String {
        guard offset >= 0, offset + count <= payload.count else { return "" }
        let slice = payload[offset..<(offset + count)]
        return String(bytes: slice, encoding: .ascii)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) ?? ""
    }

    private static func variableString(_ payload: [UInt8], at offset: Int) -> String {
        guard offset > 0, offset <= payload.count else { return "" }
        let count = Int(payload[offset - 1])
        guard count > 0, offset + count <= payload.count else { return "" }
        return ascii(payload, at: offset, count: count)
    }

    private static func firmware(_ payload: [UInt8], at offset: Int) -> String {
        guard offset + 4 <= payload.count else { return "" }
        return payload[offset..<(offset + 4)].reversed().map { String(format: "%02d", $0) }.joined(separator: ".")
    }
}
