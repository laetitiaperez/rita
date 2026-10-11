import Testing
import Foundation
@testable import RitaCore

@Suite struct BundleWriterTests {
    private static let utc = TimeZone(identifier: "UTC")!

    private func makeBundle(name: String = "A", tip: Data = Data([1]), kpp: Data = Data([2])) -> Data {
        BundleWriter.make(name: name, tipPNG: tip, kpp: kpp, preview: Data([3]), author: "L",
                          date: Date(timeIntervalSince1970: 0), timeZone: Self.utc)
    }

    private func withTempFile<T>(_ data: Data, _ body: (URL) throws -> T) throws -> T {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rita-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("test.bundle")
        try data.write(to: url)
        return try body(url)
    }

    private func unzip(_ args: [String], _ url: URL) throws -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = args + [url.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        let out = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: out, as: UTF8.self))
    }

    private func unzipEntry(_ bundle: Data, _ path: String) throws -> String {
        try withTempFile(bundle) { url in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            p.arguments = ["-p", url.path, path]
            let pipe = Pipe()
            p.standardOutput = pipe
            try p.run()
            let out = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return String(decoding: out, as: UTF8.self)
        }
    }

    @Test func zipIsValid() throws {
        let z = makeBundle(name: "Encre é 🖌", tip: Data(repeating: 7, count: 5000), kpp: Data((0..<3000).map { UInt8($0 % 251) }))
        try withTempFile(z) { url in
            let (code, out) = try unzip(["-t"], url)
            #expect(code == 0, "\(out)")
            let (code2, names) = try unzip(["-Z1"], url)
            #expect(code2 == 0)
            let lines = names.split(separator: "\n").map(String.init)
            #expect(lines.first == "mimetype")
            // unzip -Z1 déforme l'affichage des noms non ASCII : on vérifie les octets UTF-8 directement.
            #expect(z.range(of: Data("brushes/Encre é 🖌.png".utf8)) != nil)
            #expect(z.range(of: Data("paintoppresets/Encre é 🖌.kpp".utf8)) != nil)
            #expect(lines.count == 6)
            #expect(lines.contains("preview.png") && lines.contains("META-INF/manifest.xml") && lines.contains("meta.xml"))
        }
    }

    @Test func mimetypeFirstAndStored() {
        let z = makeBundle()
        #expect(z.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]))
        #expect(z.subdata(in: 30..<38) == Data("mimetype".utf8))
        #expect(z.subdata(in: 8..<10) == Data([0, 0]))
        #expect(z.subdata(in: 38..<72) == Data("application/x-krita-resourcebundle".utf8))
    }

    @Test func manifestHasMD5s() throws {
        let tip = Data([1, 2, 3]), kpp = Data([4, 5, 6])
        let z = makeBundle(tip: tip, kpp: kpp)
        let manifest = try unzipEntry(z, "META-INF/manifest.xml")
        #expect(manifest.contains("manifest:full-path=\"brushes/A.png\""))
        #expect(manifest.contains("manifest:media-type=\"brushes\""))
        #expect(manifest.contains("manifest:md5sum=\"\(Checksums.md5Hex(tip))\""))
        #expect(manifest.contains("manifest:full-path=\"paintoppresets/A.kpp\""))
        #expect(manifest.contains("manifest:media-type=\"paintoppresets\""))
        #expect(manifest.contains("manifest:md5sum=\"\(Checksums.md5Hex(kpp))\""))
        let meta = try unzipEntry(z, "meta.xml")
        #expect(meta.contains("<meta:generator>Rita "))
        #expect(meta.contains("<meta:creation-date>01/01/1970"))
        #expect(meta.contains("<dc:author>L</dc:author>"))
        #expect(meta.contains("<meta:bundle-version>1</meta:bundle-version>"))
    }

    @Test func xmlEscapesName() throws {
        let z = makeBundle(name: "A&B \"x\" <y>")
        let manifest = try unzipEntry(z, "META-INF/manifest.xml")
        #expect(manifest.contains("brushes/A&amp;B &quot;x&quot; &lt;y&gt;.png"))
        let parser = XMLParser(data: Data(manifest.utf8))
        #expect(parser.parse())
        let meta = try unzipEntry(z, "meta.xml")
        #expect(XMLParser(data: Data(meta.utf8)).parse())
    }

    @Test func sanitizesNames() {
        #expect(BundleWriter.sanitizedFileName("Encre / plume: été\u{7}") == "Encre  plume été")
        #expect(BundleWriter.sanitizedFileName("  ") == "Rita")
    }
}
