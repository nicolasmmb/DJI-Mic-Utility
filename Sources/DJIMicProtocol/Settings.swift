import Foundation

public enum SettingID: String, CaseIterable, Sendable, Hashable {
    case gain
    case monitoringGain
    case safetyTrack
    case stereo
    case lowCut
    case micLED
    case voiceTone
    case clippingControl
    case autoOffTX
    case autoOffRX
}

public enum MicSetting: Sendable, Equatable {
    case gain(Int)
    case monitoringGain(Int)
    case safetyTrack(Bool)
    case stereo(Bool)
    case lowCut(Bool)
    /// `unit == nil` targets every transmitter; `1`/`2` target a single TX.
    case micLED(Bool, unit: Int?)
    case voiceTone(VoiceTone, unit: Int)
    case clippingControl(Bool)
    case autoOffTX(Bool)
    case autoOffRX(Bool)

    public var id: SettingID {
        switch self {
        case .gain: .gain
        case .monitoringGain: .monitoringGain
        case .safetyTrack: .safetyTrack
        case .stereo: .stereo
        case .lowCut: .lowCut
        case .micLED: .micLED
        case .voiceTone: .voiceTone
        case .clippingControl: .clippingControl
        case .autoOffTX: .autoOffTX
        case .autoOffRX: .autoOffRX
        }
    }

    public var command: MicCommand {
        switch self {
        case .gain(let value):
            return MicCommand(target: .receiver, command: 0x0039, value: Self.signedByte(value))
        case .monitoringGain(let value):
            return MicCommand(target: .receiver, command: 0x0026, value: Self.signedByte(value))
        case .safetyTrack(let enabled):
            return MicCommand(target: .receiver, command: 0x0021, value: enabled ? 1 : 0)
        case .stereo(let stereo):
            return MicCommand(target: .receiver, command: 0x0008, value: stereo ? 2 : 0)
        case .lowCut(let enabled):
            return MicCommand(target: .allTransmitters, command: 0x0003, value: enabled ? 1 : 0)
        case .micLED(let enabled, let unit):
            let target: CommandTarget
            switch unit {
            case .some(1): target = .transmitter1
            case .some(2): target = .transmitter2
            default: target = .allTransmitters
            }
            return MicCommand(target: target, command: 0x000A, value: enabled ? 0 : 2)
        case .voiceTone(let tone, let unit):
            return MicCommand(
                target: unit == 2 ? .transmitter2 : .transmitter1,
                command: 0x0029,
                value: tone.commandValue
            )
        case .clippingControl(let enabled):
            return MicCommand(target: .receiver, command: 0x001E, value: enabled ? 1 : 0)
        case .autoOffTX(let enabled):
            return MicCommand(target: .allTransmitters, command: 0x0010, value: enabled ? 1 : 0)
        case .autoOffRX(let enabled):
            return MicCommand(target: .receiver, command: 0x0010, value: enabled ? 1 : 0)
        }
    }

    private static func signedByte(_ value: Int) -> UInt8 {
        UInt8(bitPattern: Int8(clamping: value))
    }
}
