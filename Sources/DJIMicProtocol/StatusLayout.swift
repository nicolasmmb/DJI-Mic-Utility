import Foundation

/// Offsets and masks that vary between device generations. The common fields
/// (gain, low cut, battery, ...) are the same; newer firmware adds optional
/// fields that older layouts leave `nil`.
public struct StatusLayout: Sendable, Equatable {
    public struct RecordingTimeOffsets: Sendable, Equatable {
        public var total: Int
        public var remaining: Int

        public init(total: Int, remaining: Int) {
            self.total = total
            self.remaining = remaining
        }
    }

    public struct Transmitter: Sendable, Equatable {
        public var muteMask: UInt8?
        public var recordingMask: UInt8?
        public var float32RecordingMask: UInt8?
        public var vibrationMask: UInt8?
        public var recStopLockMask: UInt8?
        public var startupAutoRecordingMask: UInt8?
        public var recordingTime: RecordingTimeOffsets?

        public init(
            muteMask: UInt8? = nil,
            recordingMask: UInt8? = nil,
            float32RecordingMask: UInt8? = nil,
            vibrationMask: UInt8? = nil,
            recStopLockMask: UInt8? = nil,
            startupAutoRecordingMask: UInt8? = nil,
            recordingTime: RecordingTimeOffsets? = nil
        ) {
            self.muteMask = muteMask
            self.recordingMask = recordingMask
            self.float32RecordingMask = float32RecordingMask
            self.vibrationMask = vibrationMask
            self.recStopLockMask = recStopLockMask
            self.startupAutoRecordingMask = startupAutoRecordingMask
            self.recordingTime = recordingTime
        }
    }

    public var transmitter: Transmitter

    public init(transmitter: Transmitter) {
        self.transmitter = transmitter
    }

    /// Fields present on every profile parsed so far.
    public static let common = StatusLayout(transmitter: Transmitter())

    /// DJI Mic 2 transmitter slot extensions.
    public static let mic2 = StatusLayout(
        transmitter: Transmitter(
            muteMask: 0x04,
            recordingMask: 0x10,
            float32RecordingMask: 0x08,
            vibrationMask: 0x01,
            recStopLockMask: 0x20,
            startupAutoRecordingMask: 0x80,
            recordingTime: RecordingTimeOffsets(total: 14, remaining: 16)
        )
    )
}
