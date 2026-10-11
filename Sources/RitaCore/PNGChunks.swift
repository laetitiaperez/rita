import Foundation

public enum PNGError: Error { case notPNG, badChunk }

public struct PNGChunk: Equatable, Sendable {
    public var type: String
    public var data: Data
    public init(type: String, data: Data) { self.type = type; self.data = data }
}

public enum PNGChunks {
    static let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    private static func be32(_ v: UInt32) -> Data {
        Data([UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
    }

    public static func read(_ png: Data) throws -> [PNGChunk] {
        let bytes = [UInt8](png)
        guard bytes.count >= 8, Array(bytes[0..<8]) == [UInt8](signature) else { throw PNGError.notPNG }
        var chunks: [PNGChunk] = []
        var pos = 8
        while pos < bytes.count {
            guard pos + 12 <= bytes.count else { throw PNGError.badChunk }
            let len = bytes[pos..<pos + 4].reduce(0) { ($0 << 8) | Int($1) }
            guard len <= bytes.count - pos - 12 else { throw PNGError.badChunk }
            let typeBytes = Data(bytes[pos + 4..<pos + 8])
            let body = Data(bytes[pos + 8..<pos + 8 + len])
            let stored = bytes[pos + 8 + len..<pos + 12 + len].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard stored == Checksums.crc32(typeBytes + body),
                let type = String(data: typeBytes, encoding: .isoLatin1)
            else { throw PNGError.badChunk }
            chunks.append(PNGChunk(type: type, data: body))
            pos += 12 + len
            if type == "IEND" { break }
        }
        return chunks
    }

    public static func write(_ chunks: [PNGChunk]) -> Data {
        var out = signature
        for c in chunks {
            let typeBytes = Data(c.type.utf8)
            out += be32(UInt32(c.data.count))
            out += typeBytes
            out += c.data
            out += be32(Checksums.crc32(typeBytes + c.data))
        }
        return out
    }

    public static func zlibCompress(_ d: Data) throws -> Data {
        let raw = try (d as NSData).compressed(using: .zlib) as Data
        return Data([0x78, 0x9C]) + raw + be32(Checksums.adler32(d))
    }

    public static func zlibDecompress(_ d: Data) throws -> Data {
        let bytes = [UInt8](d)
        guard bytes.count >= 6, bytes[0] & 0x0F == 8, (Int(bytes[0]) << 8 | Int(bytes[1])) % 31 == 0
        else { throw PNGError.badChunk }
        let raw = Data(bytes[2..<bytes.count - 4])
        guard let out = try? (raw as NSData).decompressed(using: .zlib) as Data else { throw PNGError.badChunk }
        let stored = bytes[(bytes.count - 4)..<bytes.count].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard stored == Checksums.adler32(out) else { throw PNGError.badChunk }
        return out
    }

    /// Valeur d'un bloc `tEXt` ou `zTXt` (UTF-8) de clé donnée, ou nil.
    public static func textValue(_ chunks: [PNGChunk], key: String) throws -> String? {
        for c in chunks where c.type == "tEXt" || c.type == "zTXt" {
            guard let nul = c.data.firstIndex(of: 0),
                let k = String(data: c.data[c.data.startIndex..<nul], encoding: .isoLatin1)
            else { throw PNGError.badChunk }
            guard k == key else { continue }
            let rest = c.data[(nul + 1)...]
            if c.type == "tEXt" { return String(decoding: rest, as: UTF8.self) }
            guard let method = rest.first, method == 0 else { throw PNGError.badChunk }
            return String(decoding: try zlibDecompress(Data(rest.dropFirst())), as: UTF8.self)
        }
        return nil
    }
}
