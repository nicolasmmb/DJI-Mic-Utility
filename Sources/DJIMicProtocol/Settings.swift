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
    case noiseControl
    case mute
    case recording
    case vibration
    case float32Recording
    case recStopLock
    case startupAutoRecording
}

/// Alias used by the device-profile layer.
public typealias SettingKey = SettingID

/// DUML command identifiers used by settings supported by this app.
public enum SettingCommandID: UInt16, Sendable {
    case recording = 0x0002
    case lowCut = 0x0003
    case vibration = 0x0004
    case stereo = 0x0008
    case mute = 0x0009
    case micLED = 0x000A
    case recStopLock = 0x000B
    case float32Recording = 0x000C
    case autoOff = 0x0010
    case clippingControl = 0x001E
    case safetyTrack = 0x0021
    case monitoringGain = 0x0026
    case voiceTone = 0x0029
    case startupAutoRecording = 0x002E
    case gain = 0x0039
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
    case mute(Bool, unit: Int)
    case recording(Bool, unit: Int)
    case vibration(Bool)
    case float32Recording(Bool)
    case recStopLock(Bool)
    case startupAutoRecording(Bool)

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
        case .mute: .mute
        case .recording: .recording
        case .vibration: .vibration
        case .float32Recording: .float32Recording
        case .recStopLock: .recStopLock
        case .startupAutoRecording: .startupAutoRecording
        }
    }

    /// Transmitter addressed by this setting, when it is unit-specific.
    public var unit: Int? {
        switch self {
        case .micLED(_, let unit):
            return unit
        case .voiceTone(_, let unit),
             .mute(_, let unit),
             .recording(_, let unit):
            return unit
        default:
            return nil
        }
    }

    /// Encoded one-byte value sent to the device.
    public var encodedValue: UInt8 {
        switch self {
        case .gain(let value), .monitoringGain(let value):
            return Self.signedByte(value)

        case .safetyTrack(let enabled),
             .lowCut(let enabled),
             .clippingControl(let enabled),
             .autoOffTX(let enabled),
             .autoOffRX(let enabled),
             .mute(let enabled, _),
             .recording(let enabled, _),
             .vibration(let enabled),
             .float32Recording(let enabled),
             .recStopLock(let enabled),
             .startupAutoRecording(let enabled):
            return enabled ? 1 : 0

        case .stereo(let stereo):
            return stereo ? 2 : 0

        case .micLED(let enabled, _):
            return enabled ? 0 : 2

        case .voiceTone(let tone, _):
            return tone.commandValue
        }
    }

    /// Legacy command mapping. Runtime sends go through
    /// `command(for: DeviceProfile)` so unsupported settings are rejected.
    public var command: MicCommand {
        MicCommand(
            target: commandTarget,
            command: commandID,
            value: encodedValue
        )
    }

    /// Resolves the command against a specific device profile. Returns `nil`
    /// when the profile does not support the setting.
    public func command(for profile: DeviceProfile) -> MicCommand? {
        guard let spec = profile.commands[id] else {
            return nil
        }

        let target: CommandTarget
        switch spec.target {
        case .receiver:
            target = .receiver
        case .broadcast:
            target = .allTransmitters
        case .unit:
            target = .transmitter(unit)
        }

        return MicCommand(target: target, command: spec.command, value: encodedValue)
    }

    private var commandTarget: CommandTarget {
        switch self {
        case .gain, .monitoringGain, .safetyTrack, .stereo,
             .clippingControl, .autoOffRX:
            return .receiver
        case .lowCut, .autoOffTX, .vibration, .float32Recording,
             .recStopLock, .startupAutoRecording:
            return .allTransmitters
        case .micLED(_, let unit):
            return .transmitter(unit)
        case .voiceTone(_, let unit),
             .mute(_, let unit),
             .recording(_, let unit):
            return .transmitter(unit)
        }
    }

    private var commandID: UInt16 {
        switch self {
        case .gain: SettingCommandID.gain.rawValue
        case .monitoringGain: SettingCommandID.monitoringGain.rawValue
        case .safetyTrack: SettingCommandID.safetyTrack.rawValue
        case .stereo: SettingCommandID.stereo.rawValue
        case .lowCut: SettingCommandID.lowCut.rawValue
        case .micLED: SettingCommandID.micLED.rawValue
        case .voiceTone: SettingCommandID.voiceTone.rawValue
        case .clippingControl: SettingCommandID.clippingControl.rawValue
        case .autoOffTX, .autoOffRX: SettingCommandID.autoOff.rawValue
        case .mute: SettingCommandID.mute.rawValue
        case .recording: SettingCommandID.recording.rawValue
        case .vibration: SettingCommandID.vibration.rawValue
        case .float32Recording: SettingCommandID.float32Recording.rawValue
        case .recStopLock: SettingCommandID.recStopLock.rawValue
        case .startupAutoRecording: SettingCommandID.startupAutoRecording.rawValue
        }
    }

    private static func signedByte(_ value: Int) -> UInt8 {
        UInt8(bitPattern: Int8(clamping: value))
    }
}
