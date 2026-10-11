import Testing
import Foundation
@testable import RitaCore

@Suite struct KPPFileTests {
    @Test func checksums() {
        #expect(Checksums.crc32(Data("123456789".utf8)) == 0xCBF43926)
        #expect(Checksums.adler32(Data("Wikipedia".utf8)) == 0x11E60398)
        #expect(Checksums.md5Hex(Data()) == "d41d8cd98f00b204e9800998ecf8427e")
    }

    @Test func readsReferencePreset() throws {
        let url = try #require(Bundle.module.url(forResource: "reference", withExtension: "kpp", subdirectory: "Resources"))
        let kpp = try Data(contentsOf: url)
        let xml = try #require(try KPPFile.presetXML(in: kpp))
        #expect(xml.hasPrefix("<Preset paintopid=\"paintbrush\" name=\"j)_WaterC_Flat_Decay_Tilt\">"))
        #expect(try PNGChunks.textValue(PNGChunks.read(kpp), key: "version") == "2.2")
    }

    @Test func roundTrip() throws {
        let thumb = RGBAImage(width: 200, height: 200, fill: (255, 255, 255, 255))
        let kpp = try KPPFile.make(thumbnail: thumb, presetXML: "<Preset name=\"é\"/>")
        #expect(try KPPFile.presetXML(in: kpp) == "<Preset name=\"é\"/>")
        let img = try ImageFile.load(data: kpp)
        #expect(img.width == 200)
        let types = try PNGChunks.read(kpp).map(\.type)
        #expect(types.prefix(3) == ["IHDR", "zTXt", "tEXt"] && types.last == "IEND")
    }

    @Test func notPNGAndBadCRCThrow() throws {
        #expect(throws: PNGError.self) { try PNGChunks.read(Data("hello".utf8)) }
        var kpp = try KPPFile.make(thumbnail: RGBAImage(width: 4, height: 4, fill: (0, 0, 0, 255)), presetXML: "<a/>")
        kpp[kpp.count - 1] ^= 0xFF
        #expect(throws: PNGError.self) { try PNGChunks.read(kpp) }
    }

    @Test func zlibRoundTripAndAdlerCheck() throws {
        let d = Data((0..<5000).map { UInt8($0 % 7) })
        var z = try PNGChunks.zlibCompress(d)
        #expect(try PNGChunks.zlibDecompress(z) == d)
        z[z.count - 1] ^= 0xFF
        #expect(throws: PNGError.self) { try PNGChunks.zlibDecompress(z) }
    }

    @Test func thumbnailIsFlattenedOnWhite() throws {
        let kpp = try KPPFile.make(thumbnail: RGBAImage(width: 2, height: 2, fill: (0, 0, 0, 0)), presetXML: "<a/>")
        let img = try ImageFile.load(data: kpp)
        #expect(img.pixel(x: 0, y: 0) == (255, 255, 255, 255))
    }
}
