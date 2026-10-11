import Foundation

/// Écrit une archive zip dont toutes les entrées sont stockées (méthode 0).
public struct ZipWriter {
    private struct Entry {
        let name: Data
        let crc: UInt32
        let size: UInt32
        let offset: UInt32
    }

    private var body = Data()
    private var entries: [Entry] = []

    // Date DOS fixe : 2026-01-01 00:00:00.
    private static let dosDate: UInt16 = ((2026 - 1980) << 9) | (1 << 5) | 1
    private static let dosTime: UInt16 = 0
    private static let utf8Flag: UInt16 = 1 << 11

    public init() {}

    public mutating func add(path: String, data: Data) {
        let name = Data(path.utf8)
        let crc = Checksums.crc32(data)
        let entry = Entry(name: name, crc: crc, size: UInt32(data.count), offset: UInt32(body.count))
        entries.append(entry)
        body.append(le32(0x0403_4B50))
        body.append(le16(20))
        body.append(le16(Self.utf8Flag))
        body.append(le16(0))
        body.append(le16(Self.dosTime))
        body.append(le16(Self.dosDate))
        body.append(le32(crc))
        body.append(le32(entry.size))
        body.append(le32(entry.size))
        body.append(le16(UInt16(name.count)))
        body.append(le16(0))
        body.append(name)
        body.append(data)
    }

    public func finish() -> Data {
        var out = body
        let cdStart = out.count
        for e in entries {
            out.append(le32(0x0201_4B50))
            out.append(le16(20))
            out.append(le16(20))
            out.append(le16(Self.utf8Flag))
            out.append(le16(0))
            out.append(le16(Self.dosTime))
            out.append(le16(Self.dosDate))
            out.append(le32(e.crc))
            out.append(le32(e.size))
            out.append(le32(e.size))
            out.append(le16(UInt16(e.name.count)))
            out.append(le16(0))
            out.append(le16(0))
            out.append(le16(0))
            out.append(le16(0))
            out.append(le32(0))
            out.append(le32(e.offset))
            out.append(e.name)
        }
        let cdSize = out.count - cdStart
        out.append(le32(0x0605_4B50))
        out.append(le16(0))
        out.append(le16(0))
        out.append(le16(UInt16(entries.count)))
        out.append(le16(UInt16(entries.count)))
        out.append(le32(UInt32(cdSize)))
        out.append(le32(UInt32(cdStart)))
        out.append(le16(0))
        return out
    }

    private func le16(_ v: UInt16) -> Data { Data([UInt8(v & 0xFF), UInt8(v >> 8)]) }
    private func le32(_ v: UInt32) -> Data {
        Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8(v >> 24)])
    }
}
