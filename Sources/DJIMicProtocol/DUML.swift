import Foundation

public enum DUML {
    public static let startOfFrame: UInt8 = 0x55
    public static let protocolVersion: UInt8 = 0x04
    public static let commandLength = 22
    public static let commandSet: UInt8 = 0x5B
    public static let heartbeatCommand: UInt8 = 0x03
    public static let maxFrameLength = 2048
}

public enum DUMLPushType: UInt8, Sendable {
    case identity = 0x01
    case status = 0x03
    case level = 0x05
}

public enum CommandTarget: UInt16, Sendable, Equatable {
    case receiver = 0x0000
    case transmitter1 = 0x0001
    case transmitter2 = 0x0002
    case allTransmitters = 0xFFFF

    /// Maps a transmitter unit to its command target. `nil` addresses every
    /// paired transmitter.
    public static func transmitter(_ unit: Int?) -> CommandTarget {
        switch unit {
        case .some(1): .transmitter1
        case .some(2): .transmitter2
        default: .allTransmitters
        }
    }
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

        // Header, length and CRC-8.
        packet[0] = DUML.startOfFrame
        packet[1] = UInt8(DUML.commandLength)
        packet[2] = DUML.protocolVersion
        packet[3] = CRC.crc8(packet[0..<3])

        // DUML v2 envelope.
        packet[4] = 0x02
        packet[5] = 0x5A
        packet[6] = UInt8(sequence & 0xFF)
        packet[7] = UInt8((sequence >> 8) & 0xFF)
        packet[8] = 0x40

        // Command set and payload.
        packet[9] = DUML.commandSet
        packet[10] = 0x01
        packet[11] = 0x02
        packet[12] = UInt8(target.rawValue & 0xFF)
        packet[13] = UInt8((target.rawValue >> 8) & 0xFF)
        packet[16] = UInt8(command & 0xFF)
        packet[17] = UInt8((command >> 8) & 0xFF)
        packet[18] = 0x01
        packet[19] = value

        // CRC-16 over everything before the checksum.
        let checksum = CRC.crc16(packet[0..<20])
        packet[20] = UInt8(checksum & 0xFF)
        packet[21] = UInt8((checksum >> 8) & 0xFF)

        return packet
    }
}

public struct CommandFrame: Equatable, Sendable {
    public var target: UInt16
    public var command: UInt16
    public var payload: [UInt8]

    public init(target: UInt16, command: UInt16, payload: [UInt8]) {
        self.target = target
        self.command = command
        self.payload = payload
    }
}

public struct AckResult: Equatable, Sendable {
    public var sequence: UInt16
    public var value: UInt8

    public init(sequence: UInt16, value: UInt8) {
        self.sequence = sequence
        self.value = value
    }

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

    public init(receiver: DeviceIdentity?, transmitters: [Int: DeviceIdentity]) {
        self.receiver = receiver
        self.transmitters = transmitters
    }
}

public struct StatusPush: Equatable, Sendable {
    public var receiver: ReceiverState?
    public var transmitters: [Int: TransmitterState]

    public init(receiver: ReceiverState?, transmitters: [Int: TransmitterState]) {
        self.receiver = receiver
        self.transmitters = transmitters
    }
}

public struct LevelPush: Equatable, Sendable {
    public var levels: [Int: Int]

    public init(levels: [Int: Int]) {
        self.levels = levels
    }
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

    public init(raw: [UInt8], content: FrameContent) {
        self.raw = raw
        self.content = content
    }

    public var isAcknowledgement: Bool {
        if case .ack = content { return true }
        return false
    }
}
