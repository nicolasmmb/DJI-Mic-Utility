import DJIMicUSB
import Foundation

/// Native IOKit bulk transport for the DJI receiver.
///
/// The class is intentionally protocol-agnostic: it only moves bytes between
/// the host and the interface endpoints. Parsing and command semantics live in
/// `DJIMicProtocol`/`DJIMicSession`.
public final class IOKitUSBTransport: USBTransporting {
    public let descriptor: USBDeviceDescriptor
    private var handle: OpaquePointer?

    public init(descriptor: USBDeviceDescriptor = .djiMicReceiver) {
        self.descriptor = descriptor
    }

    deinit {
        close()
    }

    public var isOpen: Bool {
        handle != nil
    }

    public func open() throws {
        guard handle == nil else { return }

        let opened = dji_usb_open(
            descriptor.vendorID,
            descriptor.productID,
            descriptor.interfaceNumber
        )

        guard let opened else {
            throw mapOpenError()
        }

        handle = opened
    }

    public func close() {
        guard let handle else { return }
        self.handle = nil
        dji_usb_close(handle)
    }

    public func write(_ data: Data, timeout: TimeInterval = 1.0) throws {
        guard let handle else { throw USBTransportError.notOpen }
        guard !data.isEmpty else { return }

        let result = data.withUnsafeBytes { buffer -> Int32 in
            guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else {
                return Int32(DJI_USB_INVALID)
            }
            return dji_usb_write(handle, base, UInt32(data.count), Self.milliseconds(timeout))
        }

        switch result {
        case Int32(data.count):
            return
        case Int32(DJI_USB_TIMEOUT):
            throw USBTransportError.timeout
        case Int32(DJI_USB_INVALID):
            throw USBTransportError.invalid
        default:
            throw USBTransportError.io(lastError())
        }
    }

    public func read(maxLength: Int = 1024, timeout: TimeInterval = 1.0) throws -> Data? {
        guard let handle else { throw USBTransportError.notOpen }
        guard maxLength > 0 else { throw USBTransportError.invalid }

        var buffer = [UInt8](repeating: 0, count: maxLength)
        var length = UInt32(maxLength)

        let result: Int32 = buffer.withUnsafeMutableBufferPointer { pointer in
            guard let base = pointer.baseAddress else {
                return Int32(DJI_USB_INVALID)
            }
            return dji_usb_read(handle, base, &length, Self.milliseconds(timeout))
        }

        switch result {
        case 0:
            return Data(buffer.prefix(Int(length)))
        case Int32(DJI_USB_TIMEOUT):
            return nil
        case Int32(DJI_USB_INVALID):
            throw USBTransportError.invalid
        default:
            throw USBTransportError.io(lastError())
        }
    }

    private func mapOpenError() -> USBTransportError {
        switch dji_usb_last_error_code() {
        case Int32(DJI_USB_NOT_FOUND):
            return .notFound
        case Int32(DJI_USB_ACCESS):
            return .accessDenied(lastError())
        case Int32(DJI_USB_INVALID):
            return .invalid
        default:
            return .io(lastError())
        }
    }

    private func lastError() -> String {
        guard let pointer = dji_usb_last_error() else { return "unknown USB error" }
        let message = String(cString: pointer)
        return message.isEmpty ? "unknown USB error" : message
    }

    private static func milliseconds(_ interval: TimeInterval) -> UInt32 {
        let value = max(0, interval * 1000)
        return UInt32(min(value, TimeInterval(UInt32.max)))
    }
}
