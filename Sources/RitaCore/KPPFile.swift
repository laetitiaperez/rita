import Foundation

public enum KPPFile {
    /// PNG (vignette aplatie sur blanc) + `zTXt preset` + `tEXt version=2.2` juste après `IHDR`.
    public static func make(thumbnail: RGBAImage, presetXML: String) throws -> Data {
        var flat = thumbnail
        for i in 0..<(flat.width * flat.height) {
            let a = Double(flat.pixels[4 * i + 3]) / 255
            for c in 0..<3 {
                let v = Double(flat.pixels[4 * i + c]) * a + 255 * (1 - a)
                flat.pixels[4 * i + c] = UInt8(min(255, v.rounded()))
            }
            flat.pixels[4 * i + 3] = 255
        }
        let chunks = try PNGChunks.read(ImageFile.pngData(flat))
        guard let ihdr = chunks.first, ihdr.type == "IHDR" else { throw PNGError.badChunk }
        let others = chunks.dropFirst().filter { !["tEXt", "zTXt", "iTXt"].contains($0.type) }

        var z = Data("preset".utf8)
        z.append(contentsOf: [0, 0])
        z += try PNGChunks.zlibCompress(Data(presetXML.utf8))
        let t = Data("version".utf8) + [0] + Data("2.2".utf8)

        return PNGChunks.write(
            [ihdr, PNGChunk(type: "zTXt", data: z), PNGChunk(type: "tEXt", data: t)] + others)
    }

    public static func presetXML(in kpp: Data) throws -> String? {
        try PNGChunks.textValue(PNGChunks.read(kpp), key: "preset")
    }
}
