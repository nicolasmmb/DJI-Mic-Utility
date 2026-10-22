import DJIMicProtocol
import DJIMicTransport
import Foundation

/// Owns the USB connection, sequence numbers, acknowledgements and the
/// consolidated device state. The UI never touches IOKit or raw frames.
public final class MicSession: MicClient, @unchecked Sendable {
    public let snapshots: AsyncStream<DeviceSnapshot>
    public let events: AsyncStream<SessionEvent>

    private enum Timing {
        static let readChunkSize = 1024
        static let readTimeout: TimeInterval = 0.2
        static let writeTimeout: TimeInterval = 0.5
        static let acknowledgementTimeout: TimeInterval = 2.0
    }

    private let snapshotContinuation: AsyncStream<DeviceSnapshot>.Continuation
    private let eventContinuation: AsyncStream<SessionEvent>.Continuation
    private let transport: USBTransporting
    private let queue = DispatchQueue(label: "com.niko.djimic.usb", qos: .userInitiated)
    private let reconnectDelay: TimeInterval
    private let reducer = DeviceStateReducer()

    private var running = false
    private var hasConnected = false
    private var parser = DUMLParser()
    private var state = DeviceSnapshot()
    private var lastPublished: DeviceSnapshot?
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

    // MARK: - Lifecycle

    public func start() {
        queue.async {
            guard !self.running else { return }
            self.running = true
            self.setConnection(.connecting)
            self.scheduleNextRead()
        }
    }

    public func stop() {
        queue.async {
            self.running = false
            self.transport.close()
            self.failPending(.disconnected)
            self.setConnection(.disconnected)
        }
    }

    public func reconnect() {
        queue.async {
            self.transport.close()
        }
    }

    // MARK: - Commands

    public func send(_ setting: MicSetting) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                self.dispatch(setting, continuation: continuation)
            }
        }
    }

    private var canSend: Bool {
        running && state.connection.isConnected && transport.isOpen
    }

    private func dispatch(_ setting: MicSetting, continuation: CheckedContinuation<Void, Error>) {
        guard canSend else {
            continuation.resume(throwing: MicSessionError.disconnected)
            return
        }

        let sequence = nextSequence()
        pending[sequence] = continuation
        scheduleAcknowledgementTimeout(for: sequence)
        write(setting.command.encoded(sequence: sequence), sequence: sequence)
    }

    private func write(_ packet: [UInt8], sequence: UInt16) {
        do {
            try transport.write(Data(packet), timeout: Timing.writeTimeout)
        } catch {
            resolve(
                sequence,
                result: .failure(MicSessionError.transport(String(describing: error)))
            )
        }
    }

    // MARK: - Read loop

    /// Schedules one blocking read tick. Keeping each tick as a separate
    /// queue item lets queued commands run between reads on the same serial
    /// queue, so the transport is never accessed concurrently.
    private func scheduleNextRead(after delay: TimeInterval = 0) {
        guard delay > 0 else {
            queue.async { [weak self] in
                self?.readTick()
            }
            return
        }

        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.readTick()
        }
    }

    private func readTick() {
        guard running else { return }

        guard transport.isOpen || openConnection() else {
            scheduleNextRead(after: reconnectDelay)
            return
        }

        let didFail = readAvailableData()
        scheduleNextRead(after: didFail ? reconnectDelay : 0)
    }

    private func openConnection() -> Bool {
        do {
            try transport.open()
            parser.reset()
            hasConnected = true
            setConnection(.connected)
            log("USB interface opened")
            return true
        } catch {
            setConnection(hasConnected ? .reconnecting : .disconnected)
            log("USB open failed: \(error)")
            return false
        }
    }

    /// Returns `true` when the read failed and the session must wait before
    /// retrying.
    private func readAvailableData() -> Bool {
        do {
            guard let data = try transport.read(
                maxLength: Timing.readChunkSize,
                timeout: Timing.readTimeout
            ) else {
                return false
            }

            for frame in parser.feed(data) {
                handle(frame)
            }
            return false
        } catch {
            handleReadFailure(error)
            return true
        }
    }

    private func handleReadFailure(_ error: Error) {
        log("USB read failed: \(error)")
        transport.close()
        parser.reset()
        hasConnected = true
        failPending(.disconnected)
        setConnection(.reconnecting)
    }

    // MARK: - Frame handling

    private func handle(_ frame: ParsedFrame) {
        eventContinuation.yield(.frame(raw: frame.raw, summary: frame.technicalSummary))

        switch frame.content {
        case .ack(let acknowledgement):
            resolve(
                acknowledgement.sequence,
                result: acknowledgement.accepted
                    ? .success(())
                    : .failure(MicSessionError.rejected)
            )
        default:
            reducer.apply(frame.content, to: &state)
            state.updatedAt = Date()
            publish()
        }
    }

    // MARK: - State publication

    private func setConnection(_ connection: ConnectionState) {
        state.connection = connection
        state.updatedAt = Date()
        publish()
    }

    private func publish(force: Bool = false) {
        if !force, let lastPublished, lastPublished == state {
            return
        }
        lastPublished = state
        snapshotContinuation.yield(state)
    }

    private func log(_ message: String) {
        eventContinuation.yield(.log(message))
    }

    // MARK: - Acknowledgements

    private func nextSequence() -> UInt16 {
        sequence &+= 1
        return sequence
    }

    private func scheduleAcknowledgementTimeout(for sequence: UInt16) {
        queue.asyncAfter(deadline: .now() + Timing.acknowledgementTimeout) { [weak self] in
            self?.resolve(sequence, result: .failure(MicSessionError.timeout))
        }
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
