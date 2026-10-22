import Foundation

public enum VoiceTone: String, CaseIterable, Sendable, Hashable {
    case regular
    case rich
    case bright

    public var commandValue: UInt8 {
        switch self {
        case .regular: 0
        case .rich: 1
        case .bright: 2
        }
    }
}

public struct DeviceIdentity: Equatable, Sendable {
    public var productName: String
    public var serial: String
    public var firmware: String
    public var addressSuffix: String

    public init(productName: String, serial: String, firmware: String, addressSuffix: String) {
        self.productName = productName
        self.serial = serial
        self.firmware = firmware
        self.addressSuffix = addressSuffix
    }
}

public struct ReceiverState: Equatable, Sendable {
    public var noiseCancelEnabled: Bool
    public var noiseCancelStrong: Bool
    public var gain: Int
    public var monitoringGain: Int
    public var stereo: Bool
    public var safetyTrack: Bool
    public var clippingControl: Bool
    public var autoOff: Bool
    public var flags9: UInt8
    public var flags10: UInt8
    public var flags37: UInt8

    public init(
        noiseCancelEnabled: Bool,
        noiseCancelStrong: Bool,
        gain: Int,
        monitoringGain: Int,
        stereo: Bool,
        safetyTrack: Bool,
        clippingControl: Bool,
        autoOff: Bool,
        flags9: UInt8,
        flags10: UInt8,
        flags37: UInt8
    ) {
        self.noiseCancelEnabled = noiseCancelEnabled
        self.noiseCancelStrong = noiseCancelStrong
        self.gain = gain
        self.monitoringGain = monitoringGain
        self.stereo = stereo
        self.safetyTrack = safetyTrack
        self.clippingControl = clippingControl
        self.autoOff = autoOff
        self.flags9 = flags9
        self.flags10 = flags10
        self.flags37 = flags37
    }
}

public struct TransmitterState: Equatable, Sendable, Identifiable {
    public var unit: Int
    public var noiseCancelEnabled: Bool
    public var noiseCancelStrong: Bool
    public var noiseCancelViaButton: Bool
    public var lowCut: Bool
    public var ledsOff: Bool
    public var autoOff: Bool
    public var autoOffTimerActive: Bool
    public var clippingControl: Bool
    public var voiceTone: VoiceTone
    public var charging: Bool
    public var batteryGauge: Int
    public var inputLevel: Int?

    public var id: Int { unit }

    public init(
        unit: Int,
        noiseCancelEnabled: Bool = false,
        noiseCancelStrong: Bool = false,
        noiseCancelViaButton: Bool = false,
        lowCut: Bool = false,
        ledsOff: Bool = false,
        autoOff: Bool = false,
        autoOffTimerActive: Bool = false,
        clippingControl: Bool = false,
        voiceTone: VoiceTone = .regular,
        charging: Bool = false,
        batteryGauge: Int = 0,
        inputLevel: Int? = nil
    ) {
        self.unit = unit
        self.noiseCancelEnabled = noiseCancelEnabled
        self.noiseCancelStrong = noiseCancelStrong
        self.noiseCancelViaButton = noiseCancelViaButton
        self.lowCut = lowCut
        self.ledsOff = ledsOff
        self.autoOff = autoOff
        self.autoOffTimerActive = autoOffTimerActive
        self.clippingControl = clippingControl
        self.voiceTone = voiceTone
        self.charging = charging
        self.batteryGauge = batteryGauge
        self.inputLevel = inputLevel
    }

    /// Gauge 1 = full, 7 = empty. The value is not a percentage.
    public var batteryIsFull: Bool { batteryGauge == 1 }
    public var batteryIsLow: Bool { batteryGauge >= 6 }
}

public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(String)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

public struct DeviceSnapshot: Equatable, Sendable {
    public var connection: ConnectionState
    public var receiverIdentity: DeviceIdentity?
    public var transmitterIdentities: [Int: DeviceIdentity]
    public var receiver: ReceiverState?
    public var transmitters: [Int: TransmitterState]
    public var updatedAt: Date

    public init(
        connection: ConnectionState = .disconnected,
        receiverIdentity: DeviceIdentity? = nil,
        transmitterIdentities: [Int: DeviceIdentity] = [:],
        receiver: ReceiverState? = nil,
        transmitters: [Int: TransmitterState] = [:],
        updatedAt: Date = Date()
    ) {
        self.connection = connection
        self.receiverIdentity = receiverIdentity
        self.transmitterIdentities = transmitterIdentities
        self.receiver = receiver
        self.transmitters = transmitters
        self.updatedAt = updatedAt
    }

    public var sortedTransmitters: [TransmitterState] {
        transmitters.values.sorted { $0.unit < $1.unit }
    }

    public var primaryIdentity: DeviceIdentity? {
        receiverIdentity ?? transmitterIdentities[1]
    }

    public var menuBarSymbol: String {
        connection.isConnected ? "mic.fill" : "mic.slash"
    }

    /// `updatedAt` is intentionally excluded: the UI only needs to redraw
    /// when actual device state changes.
    public static func == (lhs: DeviceSnapshot, rhs: DeviceSnapshot) -> Bool {
        lhs.connection == rhs.connection &&
            lhs.receiverIdentity == rhs.receiverIdentity &&
            lhs.transmitterIdentities == rhs.transmitterIdentities &&
            lhs.receiver == rhs.receiver &&
            lhs.transmitters == rhs.transmitters
    }
}
