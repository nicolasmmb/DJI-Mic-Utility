import DJIMicProtocol
@testable import DJIMicSession
import DJIMicTransport
import Foundation
import Testing

private final class FakeTransport: USBTransporting, @unchecked Sendable {
    enum Mode {
        case accept
        case reject
    }

    private let lock = NSLock()
    private var incoming: [Data] = []
    private var opened = false
    var mode: Mode = .accept

    var isOpen: Bool {
        lock.withLock { opened }
    }

    func open() throws {
        lock.withLock { opened = true }
    }

    func close() {
        lock.withLock { opened = false }
    }

    func write(_ data: Data, timeout: TimeInterval) throws {
        let bytes = [UInt8](data)
        guard bytes.count >= 8 else { return }
        let sequence = UInt16(bytes[6]) | (UInt16(bytes[7]) << 8)
        let value: UInt8 = mode == .accept ? 0x00 : 0xFF
        enqueue(Self.ack(sequence: sequence, value: value))
    }

    func read(maxLength: Int, timeout: TimeInterval) throws -> Data? {
        let data = lock.withLock { incoming.isEmpty ? nil : incoming.removeFirst() }
        if data == nil {
            Thread.sleep(forTimeInterval: 0.01)
        }
        return data
    }

    func enqueue(_ data: Data) {
        lock.withLock { incoming.append(data) }
    }

    private static func ack(sequence: UInt16, value: UInt8) -> Data {
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
        return Data(packet)
    }
}

private func waitForConnection(_ session: MicSession) async -> Bool {
    var iterator = session.snapshots.makeAsyncIterator()
    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline {
        guard let snapshot = await iterator.next() else { return false }
        if snapshot.connection.isConnected {
            return true
        }
    }
    return false
}

@Test func reducerPreservesInputLevelAcrossStatusPushes() {
    var state = DeviceSnapshot(
        connection: .connected,
        transmitters: [1: TransmitterState(unit: 1, inputLevel: 42)]
    )
    let status = StatusPush(
        receiver: nil,
        transmitters: [1: TransmitterState(unit: 1, batteryGauge: 2)]
    )

    DeviceStateReducer().apply(.push(.status(status)), to: &state)

    #expect(state.transmitters[1]?.inputLevel == 42)
    #expect(state.transmitters[1]?.batteryGauge == 2)
}

@Test func reducerAppliesLevelPushOnlyToKnownTransmitters() {
    var state = DeviceSnapshot(
        connection: .connected,
        transmitters: [1: TransmitterState(unit: 1)]
    )

    DeviceStateReducer().apply(.push(.level(LevelPush(levels: [1: 30, 9: 80]))), to: &state)

    #expect(state.transmitters[1]?.inputLevel == 30)
    #expect(state.transmitters[9] == nil)
}

@Test func acceptsCommandAcknowledgement() async throws {
    let transport = FakeTransport()
    let session = MicSession(transport: transport)
    session.start()
    defer { session.stop() }

    let connected = await waitForConnection(session)
    #expect(connected)
    try await session.send(.gain(0))
}

@Test func reportsRejectedCommand() async throws {
    let transport = FakeTransport()
    transport.mode = .reject
    let session = MicSession(transport: transport)
    session.start()
    defer { session.stop() }

    let connected = await waitForConnection(session)
    #expect(connected)
    var didReject = false
    do {
        try await session.send(.gain(0))
    } catch MicSessionError.rejected {
        didReject = true
    }
    #expect(didReject)
}
