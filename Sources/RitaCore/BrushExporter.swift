import Foundation

/// Assemble la pointe, le preset `.kpp` et le `.bundle` Krita.
public enum BrushExporter {
    public static func makeBundle(tip: RGBAImage, settings: BrushSettings,
                                  author: String = "Laetitia Perez", date: Date = .now) throws -> Data {
        let file = BundleWriter.sanitizedFileName(settings.name)
        let white: (UInt8, UInt8, UInt8, UInt8) = (255, 255, 255, 255)
        let xml = PresetXML.make(settings, tipFileName: "\(file).png",
                                 tipSize: (width: tip.width, height: tip.height))
        let thumbnail = StrokeSimulator.render(tip: tip, settings: settings, width: 200, height: 200, background: white)
        let preview = StrokeSimulator.render(tip: tip, settings: settings, width: 256, height: 256, background: white)
        return BundleWriter.make(
            name: settings.name,
            tipPNG: try ImageFile.pngData(tip),
            kpp: try KPPFile.make(thumbnail: thumbnail, presetXML: xml),
            preview: try ImageFile.pngData(preview),
            author: author, date: date)
    }
}
