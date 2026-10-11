import Testing
import Foundation
@testable import RitaCore

private struct Parsed { var presetName = ""; var paintopid = ""; var params: [String: String] = [:] }

private final class Collector: NSObject, XMLParserDelegate {
    var out = Parsed()
    private var current: String?
    private var text = ""
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String] = [:]) {
        if name == "Preset" { out.presetName = a["name"] ?? ""; out.paintopid = a["paintopid"] ?? "" }
        if name == "param" { current = a["name"]; text = "" }
    }
    func parser(_ parser: XMLParser, foundCDATA data: Data) { text += String(decoding: data, as: UTF8.self) }
    func parser(_ parser: XMLParser, foundCharacters s: String) { if current != nil { text += s } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "param", let c = current { out.params[c] = text; current = nil }
    }
}

private func parse(_ xml: String) throws -> Parsed {
    let p = XMLParser(data: Data(xml.utf8))
    let c = Collector()
    p.delegate = c
    guard p.parse() else { throw p.parserError ?? CocoaError(.fileReadCorruptFile) }
    return c.out
}

@Suite struct PresetXMLTests {
    @Test func containsPressureParams() throws {
        var s = BrushSettings.default
        s.options[.size] = .init(enabled: true, strength: 0.8, curve: .soft)
        let p = try parse(PresetXML.make(s, tipFileName: "Encre.png", tipSize: (200, 100)))
        #expect(p.paintopid == "paintbrush")
        #expect(p.params["PressureSize"] == "true")
        #expect(p.params["PressureRotation"] == "false")
        #expect(p.params["SizeValue"] == "0.8")
        #expect(p.params["SizecommonCurve"] == "0,0;0.5,0.25;1,1;")
        #expect(p.params["SizeSensor"]!.contains("<params id=\"pressure\"> <curve>0,0;0.5,0.25;1,1;</curve>"))
        #expect(p.params["SizeUseCurve"] == "true")
        #expect(p.params["SizeUseSameCurve"] == "true")
        #expect(p.params["SizecurveMode"] == "0")
        #expect(p.params["paintop"] == "paintbrush")
        #expect(p.params["CompositeOp"] == "normal")
        #expect(p.params["EraserMode"] == "false")
        #expect(p.params["Scattering/AxisX"] == "true")
        #expect(p.params["Scattering/AxisY"] == "true")
        #expect(p.params["Spacing/Isotropic"] == "false")
        #expect(p.params["Texture/Pattern/Enabled"] == "false")
        #expect(p.params["MaskingBrush/Enabled"] == "false")
        #expect(p.params["lodUserAllowed"] == "true")
        #expect(p.params["requiredBrushFile"] == "Encre.png")
        #expect(p.params["requiredBrushFilesList"] == "Encre.png")
        for k in PressureKind.allCases {
            #expect(p.params["Pressure\(k.kritaKey)"] != nil)
            #expect(p.params["\(k.kritaKey)Sensor"] != nil)
        }
    }

    @Test func paramsAreSortedByName() throws {
        let xml = PresetXML.make(.default, tipFileName: "x.png", tipSize: (10, 10))
        let names = xml.components(separatedBy: "<param type=\"string\" name=\"").dropFirst()
            .map { String($0.prefix { $0 != "\"" }) }
        #expect(names.count > 20)
        #expect(names == names.sorted())
    }

    @Test(arguments: [
        (TipMode.mask, "1", "0", "0"),
        (TipMode.colorImage, "0", "0", "1"),
        (TipMode.lightnessMap, "0", "1", "2"),
    ])
    func brushDefinitionModes(mode: TipMode, mask: String, lightness: String, application: String) throws {
        var s = BrushSettings.default
        s.tipMode = mode; s.diameter = 40; s.spacing = 0.1
        let p = try parse(PresetXML.make(s, tipFileName: "Encre.png", tipSize: (200, 100)))
        let d = try #require(p.params["brush_definition"])
        #expect(d.contains("filename=\"Encre.png\""))
        #expect(d.contains("type=\"png_brush\""))
        #expect(d.contains("BrushVersion=\"2\""))
        #expect(d.contains("scale=\"0.2\""))
        #expect(d.contains("spacing=\"0.1\""))
        #expect(d.contains("angle=\"0\""))
        #expect(d.contains("useAutoSpacing=\"0\""))
        #expect(d.contains("autoSpacingCoeff=\"1\""))
        #expect(d.contains("ColorAsMask=\"\(mask)\""))
        #expect(d.contains("preserveLightness=\"\(lightness)\""))
        #expect(d.contains("brushApplication=\"\(application)\""))
        #expect(d.contains("BrightnessAdjustment=\"0\""))
        #expect(d.contains("ContrastAdjustment=\"0\""))
        #expect(d.contains("AdjustmentMidPoint=\"127\""))
    }

    @Test func escapesName() throws {
        var s = BrushSettings.default
        s.name = "Encre & \"plume\" <é> 🖋"
        let p = try parse(PresetXML.make(s, tipFileName: "x.png", tipSize: (10, 10)))
        #expect(p.presetName == "Encre & \"plume\" <é> 🖋")
    }

    @Test func settingsCodableRoundTrip() throws {
        var s = BrushSettings.default
        s.name = "Test"; s.tipMode = .lightnessMap; s.diameter = 123.5; s.spacing = 0.25
        s.options[.rotation] = .init(enabled: true, strength: 0.4, curve: .firm)
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(BrushSettings.self, from: data) == s)
    }

    @Test func defaults() {
        let s = BrushSettings.default
        #expect(s.name == "Rita" && s.tipMode == .mask && s.diameter == 40 && s.spacing == 0.1)
        #expect(s.options.count == PressureKind.allCases.count)
        for k in PressureKind.allCases {
            #expect(s.options[k] == .init(enabled: k == .size || k == .opacity, strength: 1, curve: .linear))
        }
        #expect(PressureKind.opacity.label == "Opacité" && PressureKind.scatter.kritaKey == "Scatter")
    }
}
