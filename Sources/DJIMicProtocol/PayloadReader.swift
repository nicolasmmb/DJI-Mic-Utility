import Foundation

/// Bounds-checked, offset-based reader for DUML payloads.
///
/// Payload layouts are positional, so the reader centralises the bounds checks
/// and keeps the parser focused on field semantics instead of index math.
struct PayloadReader {
    private let bytes: [UInt8]

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    var count: Int { bytes.count }

    func byte(at offset: Int) -> UInt8? {
        guard bytes.indices.contains(offset) else { return nil }
        return bytes[offset]
    }

    func flag(at offset: Int, mask: UInt8) -> Bool {
        guard let value = byte(at: offset) else { return false }
        return value & mask != 0
    }

    func signedByte(at offset: Int) -> Int? {
        byte(at: offset).map { Int(Int8(bitPattern: $0)) }
    }

    func uint16(at offset: Int) -> UInt16? {
        guard let low = byte(at: offset), let high = byte(at: offset + 1) else {
            return nil
        }
        return UInt16(low) | (UInt16(high) << 8)
    }

    func ascii(at offset: Int, count: Int) -> String {
        guard count > 0, offset >= 0, offset + count <= bytes.count else {
            return ""
        }
        let slice = bytes[offset..<(offset + count)]
        return String(bytes: slice, encoding: .ascii)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) ?? ""
    }

    /// Reads a string whose length is stored in the byte immediately before
    /// `offset`.
    func lengthPrefixedString(at offset: Int) -> String {
        guard offset > 0, let length = byte(at: offset - 1), length > 0 else {
            return ""
        }
        return ascii(at: offset, count: Int(length))
    }

    /// Reads a version stored little-endian and prints it as dotted decimal.
    func reversedByteString(at offset: Int, count: Int) -> String {
        guard offset >= 0, offset + count <= bytes.count else { return "" }
        return bytes[offset..<(offset + count)]
            .reversed()
            .map { String(format: "%02d", $0) }
            .joined(separator: ".")
    }
}
