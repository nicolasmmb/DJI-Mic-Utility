import DJIMicProtocol
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

/// Abstraction used by the UI layer. `MicSession` owns the USB transport and
/// protocol state; test doubles only need to provide snapshots and accept
/// settings.
public protocol MicClient: AnyObject {
    var snapshots: AsyncStream<DeviceSnapshot> { get }
    var events: AsyncStream<SessionEvent> { get }
    func start()
    func stop()
    func reconnect()
    func send(_ setting: MicSetting) async throws
}
