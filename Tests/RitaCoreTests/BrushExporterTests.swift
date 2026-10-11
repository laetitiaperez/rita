import Testing
import Foundation
@testable import RitaCore

@Suite struct BrushExporterTests {
    /// Pointe 128×128 : tache ronde douce, rouge (gauche) → bleu (droite), alpha 0 au bord.
    static func sampleTip() -> RGBAImage {
        let n = 128
        var img = RGBAImage(width: n, height: n, fill: (0, 0, 0, 0))
        let c = Double(n - 1) / 2
        for y in 0..<n {
            for x in 0..<n {
                let d = (((Double(x) - c) * (Double(x) - c) + (Double(y) - c) * (Double(y) - c)).squareRoot()) / c
                let t = min(max(1 - d, 0), 1)
                let alpha = UInt8((t * t * (3 - 2 * t) * 255).rounded())
                let u = Double(x) / Double(n - 1)
                img.setPixel(x: x, y: y, (UInt8((255 * (1 - u)).rounded()), 0, UInt8((255 * u).rounded()), alpha))
            }
        }
        return img
    }

    static func settings(name: String, mode: TipMode) -> BrushSettings {
        var s = BrushSettings.default
        s.name = name
        s.tipMode = mode
        s.diameter = 40
        s.options[.size] = PressureOption(enabled: true, strength: 1, curve: .linear)
        s.options[.opacity] = PressureOption(enabled: true, strength: 1, curve: .linear)
        s.options[.rotation] = PressureOption(enabled: true, strength: 0.5, curve: .linear)
        return s
    }

    static func unzip(_ data: Data) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let zip = dir.appendingPathComponent("b.bundle")
        try data.write(to: zip)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-q", zip.path, "-d", dir.appendingPathComponent("out").path]
        try p.run(); p.waitUntilExit()
        #expect(p.terminationStatus == 0)
        return dir.appendingPathComponent("out")
    }

    @Test func makesImportableBundle() throws {
        let s = Self.settings(name: "Encre", mode: .colorImage)
        let data = try BrushExporter.makeBundle(tip: Self.sampleTip(), settings: s)
        let out = try Self.unzip(data)
        defer { try? FileManager.default.removeItem(at: out.deletingLastPathComponent()) }

        let tip = try ImageFile.load(contentsOf: out.appendingPathComponent("brushes/Encre.png"))
        #expect(tip.width == 128 && tip.height == 128)
        let kpp = try Data(contentsOf: out.appendingPathComponent("paintoppresets/Encre.kpp"))
        let xml = try #require(try KPPFile.presetXML(in: kpp))
        #expect(xml.contains("requiredBrushFile") && xml.contains("Encre.png"))
        let thumb = try ImageFile.load(data: kpp)
        #expect(thumb.width == 200 && thumb.height == 200)
        let preview = try ImageFile.load(contentsOf: out.appendingPathComponent("preview.png"))
        #expect(preview.width == 256 && preview.height == 256)
        #expect(FileManager.default.fileExists(atPath: out.appendingPathComponent("META-INF/manifest.xml").path))
        #expect(FileManager.default.fileExists(atPath: out.appendingPathComponent("meta.xml").path))
    }

    @Test func writesSamplesIfAsked() throws {
        guard let dir = ProcessInfo.processInfo.environment["RITA_SAMPLES_DIR"], !dir.isEmpty else { return }
        let url = URL(fileURLWithPath: dir, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let samples: [(String, TipMode)] = [
            ("Rita-Masque", .mask), ("Rita-Couleur", .colorImage), ("Rita-Luminosite", .lightnessMap),
        ]
        for (name, mode) in samples {
            let data = try BrushExporter.makeBundle(tip: Self.sampleTip(), settings: Self.settings(name: name, mode: mode))
            try data.write(to: url.appendingPathComponent("\(name).bundle"))
        }
    }
}
