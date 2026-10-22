import Foundation

public enum CRC {
    private static let table8: [UInt8] = {
        (0..<256).map { value in
            var current = UInt8(value)
            for _ in 0..<8 {
                current = (current >> 1) ^ ((current & 1) == 1 ? 0x8C : 0)
            }
            return current
        }
    }()

    private static let table16: [UInt16] = {
        (0..<256).map { value in
            var current = UInt16(value)
            for _ in 0..<8 {
                current = (current >> 1) ^ ((current & 1) == 1 ? 0x8408 : 0)
            }
            return current
        }
    }()

    public static func crc8(_ bytes: [UInt8]) -> UInt8 {
        var value: UInt8 = 0x77
        for byte in bytes {
            value = table8[Int(value ^ byte)]
        }
        return value
    }

    public static func crc16(_ bytes: [UInt8]) -> UInt16 {
        var value: UInt16 = 0x3692
        for byte in bytes {
            value = (value >> 8) ^ table16[Int((value ^ UInt16(byte)) & 0xFF)]
        }
        return value
    }
}
