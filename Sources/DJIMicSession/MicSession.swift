import DJIMicProtocol
import DJIMicTransport
import Foundation

public enum MicSessionError: Error, Equatable, Sendable {
    case disconnected
    case timeout
    case rejected
    case transport(String)
}

public enum SessionEvent: Sendable {
    case frame(raw: [UInt8], summary: String)
    case log(String)
}

public protocol MicClient: AnyObject {
    var snapshots: AsyncStream<DeviceSnapshot> { get }
    var events: AsyncStream<SessionEvent> { get }
    func start()
    func stop()
    func reconnect()
    func send(_ setting: MicSetting) async throws
}

/// Owns the USB connection, sequence numbers, acknowledgements and the
/// consolidated device state. The UI never touches IOKit or raw frames.
public final class MicSession: MicClient, @unchecked Sendable {
    public let snapshots: AsyncStream<DeviceSnapshot>
    public let events: AsyncStream<SessionEvent>

    private let snapshotContinuation: AsyncStream<DeviceSnapshot>.Continuation
    private let eventContinuation: AsyncStream<SessionEvent>.Continuation
    private let transport: USBTransporting
    private let queue = DispatchQueue(label: "com.niko.djimic.usb", qos: .userInitiated)
    private let reconnectDelay: TimeInterval

    private var running = false
    private var hasConnected = false
    private var parser = DUMLParser()
    private var state = DeviceSnapshot()
    private var sequence = UInt16.random(in: 0...UInt16.max)
    private var pending: [UInt16: CheckedContinuation<Void, Error>] = [:]

    public init(
        transport: USBTransporting = IOKitUSBTransport(),
        reconnectDelay: TimeInterval = 1.0
    ) {
        self.transport = transport
        self.reconnectDelay = reconnectDelay

        var snapshotContinuation: AsyncStream<DeviceSnapshot>.Continuation!
        self.snapshots = AsyncStream(bufferingPolicy: .bufferingNewest(1)) {
            snapshotContinuation = $0
        }
        self.snapshotContinuation = snapshotContinuation

        var eventContinuation: AsyncStream<SessionEvent>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .bufferingNewest(300)) {
            eventContinuation = $0
        }
        self.eventContinuation = eventContinuation
    }

    public func start() {
        queue.async {
            guard !self.running else { return }
            self.running = true
            self.state.connection = .connecting
            self.publish()
            self.scheduleNextRead()
        }
    }

    public func stop() {
        queue.async {
            self.running = false
            self.transport.close()
            self.failPending(.disconnected)
            self.state.connection = .disconnected
            self.publish()
        }
    }

    public func reconnect() {
        queue.async {
            self.transport.close()
        }
    }

    public func send(_ setting: MicSetting) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard self.running, self.state.connection.isConnected, self.transport.isOpen else {
                    continuation.resume(throwing: MicSessionError.disconnected)
                    return
                }

                let sequence = self.nextSequence()
                let packet = setting.command.encoded(sequence: sequence)
                self.pending[sequence] = continuation

                self.queue.asyncAfter(deadline: .now() + 2.0) {
                    self.resolve(sequence, result: .failure(MicSessionError.timeout))
                }

                do {
                    try self.transport.write(Data(packet), timeout: 0.5)
                } catch {
                    self.resolve(sequence, result: .failure(MicSessionError.transport(String(describing: error))))
                }
            }
        }
    }

    // MARK: - Read loop

    /// Schedules one blocking read tick. Keeping each tick as a separate
    /// queue item lets queued commands run between reads on the same serial
    /// queue, so the transport is never accessed concurrently.
    private func scheduleNextRead() {
        queue.async { [weak self] in
            self?.readTick()
        }
    }

    private func readTick() {
        guard running else { return }

        if !transport.isOpen {
            do {
                try transport.open()
                hasConnected = true
                state.connection = .connected
                publish()
                eventContinuation.yield(.log("USB interface opened"))
            } catch {
                state.connection = hasConnected ? .reconnecting : .disconnected
                state.updatedAt = Date()
                publish()
                eventContinuation.yield(.log("USB open failed: \(error)"))
                Thread.sleep(forTimeInterval: reconnectDelay)
                scheduleNextRead()
                return
            }
        }

        do {
            if let data = try transport.read(maxLength: 1024, timeout: 0.2) {
                let frames = parser.feed(data)
                for frame in frames {
                    handle(frame)
                }
            }
        } catch {
            eventContinuation.yield(.log("USB read failed: \(error)"))
            transport.close()
            hasConnected = true
            failPending(.disconnected)
            state.connection = .reconnecting
            state.updatedAt = Date()
            publish()
            Thread.sleep(forTimeInterval: reconnectDelay)
        }

        scheduleNextRead()
    }

    // MARK: - Frame handling

    private func handle(_ frame: ParsedFrame) {
        eventContinuation.yield(.frame(raw: frame.raw, summary: frame.technicalSummary))

        switch frame.content {
        case .ack(let ack):
            if ack.accepted {
                resolve(ack.sequence, result: .success(()))
            } else {
                resolve(ack.sequence, result: .failure(MicSessionError.rejected))
            }

        case .push(.identity(let push)):
            if let receiver = push.receiver {
                state.receiverIdentity = receiver
            }
            for (unit, identity) in push.transmitters {
                state.transmitterIdentities[unit] = identity
            }

        case .push(.status(let push)):
            state.receiver = push.receiver
            var updated: [Int: TransmitterState] = [:]
            for (unit, var transmitter) in push.transmitters {
                transmitter.inputLevel = state.transmitters[unit]?.inputLevel
                updated[unit] = transmitter
            }
            state.transmitters = updated

        case .push(.level(let push)):
            for (unit, level) in push.levels {
                guard var transmitter = state.transmitters[unit] else { continue }
                transmitter.inputLevel = level
                state.transmitters[unit] = transmitter
            }

        case .push(.unknown), .command, .unknown:
            break
        }

        state.updatedAt = Date()
        publish()
    }

    private func publish() {
        snapshotContinuation.yield(state)
    }

    // MARK: - Acknowledgements

    private func nextSequence() -> UInt16 {
        sequence &+= 1
        return sequence
    }

    private func resolve(_ sequence: UInt16, result: Result<Void, Error>) {
        guard let continuation = pending.removeValue(forKey: sequence) else { return }
        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func failPending(_ error: MicSessionError) {
        let continuations = Array(pending.values)
        pending.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }
}
