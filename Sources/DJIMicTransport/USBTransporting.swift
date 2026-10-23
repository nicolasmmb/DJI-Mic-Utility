import Foundation

public enum USBTransportError: Error, Equatable {
    case notFound
    case accessDenied(String)
    case notOpen
    case timeout
    case io(String)
    case invalid
}

public protocol USBTransporting: AnyObject {
    var isOpen: Bool { get }
    func open() throws
    func close()
    func write(_ data: Data, timeout: TimeInterval) throws
    func read(maxLength: Int, timeout: TimeInterval) throws -> Data?
}

public struct USBDeviceDescriptor: Equatable, Sendable {
    public let vendorID: UInt16
    public let productID: UInt16
    public let interfaceNumber: UInt8

    public init(vendorID: UInt16, productID: UInt16, interfaceNumber: UInt8) {
        self.vendorID = vendorID
        self.productID = productID
        self.interfaceNumber = interfaceNumber
    }

    public static let djiMicReceiver = USBDeviceDescriptor(
        vendorID: 0x2CA3,
        productID: 0x4011,
        interfaceNumber: 6
    )
}
