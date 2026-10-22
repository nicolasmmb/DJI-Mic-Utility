import Foundation

/// Device families observed in the wild. Capabilities and commands are
/// resolved per component: the receiver and each transmitter can belong to
/// different families (for example a Mini 2 RX paired with Mic 2 TXs).
public enum DeviceFamily: String, Sendable, Equatable {
    case micMini2
    case mic2
    case unknown
}

/// Where a command is addressed.
public enum CommandTargetPolicy: Sendable, Equatable {
    /// Receiver itself: `0x0000`.
    case receiver
    /// Every paired transmitter: `0xFFFF`.
    case broadcast
    /// The transmitter named by the setting: `0x0001` / `0x0002`.
    case unit
}

/// Command id and target policy for one setting on one profile.
public struct CommandSpec: Sendable, Equatable {
    public var command: UInt16
    public var target: CommandTargetPolicy

    public init(command: UInt16, target: CommandTargetPolicy) {
        self.command = command
        self.target = target
    }
}

public struct DeviceCapabilities: Sendable {
    public var settings: Set<SettingID>

    public init(settings: Set<SettingID>) {
        self.settings = settings
    }

    public func supports(_ key: SettingID) -> Bool {
        settings.contains(key)
    }

    public static let none = DeviceCapabilities(settings: [])
}

/// Capabilities, command table and parse layout for one component.
public struct DeviceProfile: Sendable {
    public var family: DeviceFamily
    public var capabilities: DeviceCapabilities
    public var commands: [SettingID: CommandSpec]
    public var statusLayout: StatusLayout

    public init(
        family: DeviceFamily,
        capabilities: DeviceCapabilities,
        commands: [SettingID: CommandSpec],
        statusLayout: StatusLayout
    ) {
        self.family = family
        self.capabilities = capabilities
        self.commands = commands
        self.statusLayout = statusLayout
    }
}

/// Resolved receiver + transmitters for the connected kit.
public struct DeviceSystemProfile: Sendable {
    public var receiver: DeviceProfile
    public var transmitters: [Int: DeviceProfile]

    public init(receiver: DeviceProfile, transmitters: [Int: DeviceProfile]) {
        self.receiver = receiver
        self.transmitters = transmitters
    }

    public static let unknown = DeviceSystemProfile(
        receiver: .unknown,
        transmitters: [:]
    )

    public var isKnown: Bool {
        receiver.family != .unknown || !transmitters.isEmpty
    }

    /// The richest layout needed by any connected component. A Mini 2 RX can
    /// be paired with Mic 2 transmitters, so the transmitter layout wins when
    /// it carries extra fields.
    public var statusLayout: StatusLayout {
        let layouts = [receiver.statusLayout] + transmitters.values.map(\.statusLayout)
        return layouts.first { $0 != .common } ?? .common
    }

    /// The profile that owns a setting: receiver settings use the receiver
    /// profile; transmitter settings use the addressed unit, or the first
    /// available transmitter for broadcast settings.
    public func profile(for setting: MicSetting) -> DeviceProfile? {
        switch setting.id {
        case .gain, .monitoringGain, .safetyTrack, .stereo,
             .clippingControl, .autoOffRX, .noiseControl:
            return receiver

        case .lowCut, .micLED, .voiceTone, .autoOffTX,
             .mute, .recording, .vibration, .float32Recording,
             .recStopLock, .startupAutoRecording:
            if let unit = setting.unit, let profile = transmitters[unit] {
                return profile
            }
            return transmitters
                .sorted { $0.key < $1.key }
                .first?
                .value
        }
    }

    /// A transmitter profile if every connected TX supports the setting.
    /// Used by global controls (vibration, 32-bit float, REC stop lock...).
    public func sharedTransmitterCapability(for key: SettingID) -> DeviceProfile? {
        guard !transmitters.isEmpty else { return nil }
        let profiles = transmitters.values
        guard profiles.allSatisfy({ $0.capabilities.supports(key) }) else {
            return nil
        }
        return profiles.first
    }

    /// Resolves the full command using the owning profile.
    public func command(for setting: MicSetting) -> MicCommand? {
        guard let profile = profile(for: setting) else { return nil }
        return setting.command(for: profile)
    }
}

public enum DeviceProfileResolver {
    public static func resolve(
        receiver: DeviceIdentity?,
        transmitters: [Int: DeviceIdentity]
    ) -> DeviceSystemProfile {
        DeviceSystemProfile(
            receiver: receiverProfile(receiver),
            transmitters: transmitters.mapValues(transmitterProfile)
        )
    }

    public static func family(for identity: DeviceIdentity?) -> DeviceFamily {
        guard let name = identity?.productName, !name.isEmpty else {
            return .unknown
        }
        if name.contains("DJI Mic Mini 2") { return .micMini2 }
        if name.contains("DJI Mic 2") { return .mic2 }
        return .unknown
    }

    private static func receiverProfile(_ identity: DeviceIdentity?) -> DeviceProfile {
        switch family(for: identity) {
        case .micMini2: .micMini2Receiver
        case .mic2: .mic2Receiver
        case .unknown: .unknown
        }
    }

    private static func transmitterProfile(_ identity: DeviceIdentity) -> DeviceProfile {
        switch family(for: identity) {
        case .micMini2: .micMini2Transmitter
        case .mic2: .mic2Transmitter
        case .unknown: .unknown
        }
    }
}

// MARK: - Profiles

extension DeviceProfile {
    public static let unknown = DeviceProfile(
        family: .unknown,
        capabilities: .none,
        commands: [:],
        statusLayout: .common
    )

    /// Mini 2 receiver: common RX settings. NC is read-only because the
    /// firmware rejects writes.
    public static let micMini2Receiver = DeviceProfile(
        family: .micMini2,
        capabilities: .init(settings: [
            .gain, .monitoringGain, .safetyTrack, .stereo,
            .clippingControl, .autoOffRX,
        ]),
        commands: [
            .gain: .init(command: 0x0039, target: .receiver),
            .monitoringGain: .init(command: 0x0026, target: .receiver),
            .safetyTrack: .init(command: 0x0021, target: .receiver),
            .stereo: .init(command: 0x0008, target: .receiver),
            .clippingControl: .init(command: 0x001E, target: .receiver),
            .autoOffRX: .init(command: 0x0010, target: .receiver),
        ],
        statusLayout: .common
    )

    /// Mic 2 receiver. Noise control write is not validated on this hardware,
    /// so it is intentionally absent.
    public static let mic2Receiver = DeviceProfile(
        family: .mic2,
        capabilities: .init(settings: [
            .gain, .monitoringGain, .safetyTrack, .stereo,
            .clippingControl, .autoOffRX,
        ]),
        commands: [
            .gain: .init(command: 0x0039, target: .receiver),
            .monitoringGain: .init(command: 0x0026, target: .receiver),
            .safetyTrack: .init(command: 0x0021, target: .receiver),
            .stereo: .init(command: 0x0008, target: .receiver),
            .clippingControl: .init(command: 0x001E, target: .receiver),
            .autoOffRX: .init(command: 0x0010, target: .receiver),
        ],
        statusLayout: .mic2
    )

    /// Mini 2 transmitter: no internal recording, no mute.
    public static let micMini2Transmitter = DeviceProfile(
        family: .micMini2,
        capabilities: .init(settings: [
            .lowCut, .micLED, .voiceTone, .autoOffTX,
        ]),
        commands: [
            .lowCut: .init(command: 0x0003, target: .broadcast),
            .micLED: .init(command: 0x000A, target: .unit),
            .voiceTone: .init(command: 0x0029, target: .unit),
            .autoOffTX: .init(command: 0x0010, target: .broadcast),
        ],
        statusLayout: .common
    )

    /// Mic 2 transmitter: validated recording and button settings.
    public static let mic2Transmitter = DeviceProfile(
        family: .mic2,
        capabilities: .init(settings: [
            .lowCut, .micLED, .autoOffTX,
            .mute, .recording, .vibration, .float32Recording,
            .recStopLock, .startupAutoRecording,
        ]),
        commands: [
            .lowCut: .init(command: 0x0003, target: .broadcast),
            .micLED: .init(command: 0x000A, target: .unit),
            .autoOffTX: .init(command: 0x0010, target: .broadcast),
            .mute: .init(command: 0x0009, target: .unit),
            .recording: .init(command: 0x0002, target: .unit),
            .vibration: .init(command: 0x0004, target: .broadcast),
            .float32Recording: .init(command: 0x000C, target: .broadcast),
            .recStopLock: .init(command: 0x000B, target: .broadcast),
            .startupAutoRecording: .init(command: 0x002E, target: .broadcast),
        ],
        statusLayout: .mic2
    )
}
