import Foundation

/// Génère le XML d'un preset Krita (`paintbrush`) à partir des réglages.
public enum PresetXML {
    public static func make(_ s: BrushSettings, tipFileName: String,
                            tipSize: (width: Int, height: Int)) -> String {
        var params: [String: String] = [
            "paintop": "paintbrush",
            "CompositeOp": "normal",
            "EraserMode": "false",
            "Scattering/AxisX": "true",
            "Scattering/AxisY": "true",
            "Spacing/Isotropic": "false",
            "Texture/Pattern/Enabled": "false",
            "MaskingBrush/Enabled": "false",
            "lodUserAllowed": "true",
            "requiredBrushFile": tipFileName,
            "requiredBrushFilesList": tipFileName,
            "brush_definition": brushDefinition(s, tipFileName: tipFileName, tipSize: tipSize),
        ]
        for kind in PressureKind.allCases {
            let o = s.options[kind] ?? PressureOption(enabled: false, strength: 1, curve: .linear)
            let k = kind.kritaKey
            let curve = o.curve.description
            params["Pressure\(k)"] = o.enabled ? "true" : "false"
            params["\(k)Sensor"] = "<!DOCTYPE params> <params id=\"pressure\"> <curve>\(curve)</curve> </params> "
            params["\(k)UseCurve"] = "true"
            params["\(k)UseSameCurve"] = "true"
            params["\(k)commonCurve"] = curve
            params["\(k)curveMode"] = "0"
            params["\(k)Value"] = kritaNumber(o.strength)
        }
        var xml = "<Preset paintopid=\"paintbrush\" name=\"\(escapeAttribute(s.name))\">\n"
        for name in params.keys.sorted() {
            xml += " <param type=\"string\" name=\"\(escapeAttribute(name))\"><![CDATA[\(params[name]!)]]></param>\n"
        }
        xml += "</Preset>\n"
        return xml
    }

    private static func brushDefinition(_ s: BrushSettings, tipFileName: String,
                                        tipSize: (width: Int, height: Int)) -> String {
        let (mask, lightness, application): (Int, Int, Int) = switch s.tipMode {
        case .mask: (1, 0, 0)
        case .colorImage: (0, 0, 1)
        case .lightnessMap: (0, 1, 2)
        }
        let side = Double(max(tipSize.width, tipSize.height, 1))
        return "<Brush type=\"png_brush\" filename=\"\(escapeAttribute(tipFileName))\" BrushVersion=\"2\" "
            + "scale=\"\(kritaNumber(s.diameter / side))\" spacing=\"\(kritaNumber(s.spacing))\" angle=\"0\" "
            + "useAutoSpacing=\"0\" autoSpacingCoeff=\"1\" ColorAsMask=\"\(mask)\" "
            + "preserveLightness=\"\(lightness)\" brushApplication=\"\(application)\" "
            + "BrightnessAdjustment=\"0\" ContrastAdjustment=\"0\" AdjustmentMidPoint=\"127\"/>"
    }

    private static func escapeAttribute(_ t: String) -> String {
        t.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
