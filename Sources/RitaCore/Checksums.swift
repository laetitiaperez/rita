import CryptoKit
import Foundation

public enum Checksums {
    private static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    public static func crc32(_ d: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in d { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }

    public static func adler32(_ d: Data) -> UInt32 {
        var a: UInt32 = 1, b: UInt32 = 0
        for byte in d {
            a = (a + UInt32(byte)) % 65521
            b = (b + a) % 65521
        }
        return (b << 16) | a
    }

    public static func md5Hex(_ d: Data) -> String {
        Insecure.MD5.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
}
