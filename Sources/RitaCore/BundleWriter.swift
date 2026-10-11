import Foundation

public enum BundleWriter {
    public static func make(name: String, tipPNG: Data, kpp: Data, preview: Data, author: String,
                            date: Date, timeZone: TimeZone = .current) -> Data {
        let file = sanitizedFileName(name)
        let brushPath = "brushes/\(file).png"
        let presetPath = "paintoppresets/\(file).kpp"

        let manifest = """
        <?xml version="1.0" encoding="UTF-8"?>
        <manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">
         <manifest:file-entry manifest:media-type="application/x-krita-resourcebundle" manifest:full-path="/"/>
         <manifest:file-entry manifest:media-type="brushes" manifest:full-path="\(xmlEscape(brushPath))" manifest:md5sum="\(Checksums.md5Hex(tipPNG))"/>
         <manifest:file-entry manifest:media-type="paintoppresets" manifest:full-path="\(xmlEscape(presetPath))" manifest:md5sum="\(Checksums.md5Hex(kpp))"/>
        </manifest:manifest>

        """

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "dd/MM/yyyy"
        let day = formatter.string(from: date)
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let who = xmlEscape(author)

        let meta = """
        <?xml version="1.0" encoding="UTF-8"?>
        <meta:meta xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
         <meta:generator>Rita \(xmlEscape(version))</meta:generator>
         <meta:bundle-version>1</meta:bundle-version>
         <dc:author>\(who)</dc:author>
         <dc:description>Brush créée avec Rita</dc:description>
         <meta:initial-creator>\(who)</meta:initial-creator>
         <dc:creator>\(who)</dc:creator>
         <meta:creation-date>\(day)</meta:creation-date>
         <meta:dc-date>\(day)</meta:dc-date>
        </meta:meta>

        """

        var zip = ZipWriter()
        zip.add(path: "mimetype", data: Data("application/x-krita-resourcebundle".utf8))
        zip.add(path: brushPath, data: tipPNG)
        zip.add(path: presetPath, data: kpp)
        zip.add(path: "preview.png", data: preview)
        zip.add(path: "META-INF/manifest.xml", data: Data(manifest.utf8))
        zip.add(path: "meta.xml", data: Data(meta.utf8))
        return zip.finish()
    }

    public static func sanitizedFileName(_ name: String) -> String {
        let kept = name.unicodeScalars.filter { s in
            !"/:\\".unicodeScalars.contains(s) && !CharacterSet.controlCharacters.contains(s)
        }
        var out = String(String.UnicodeScalarView(kept)).trimmingCharacters(in: .whitespaces)
        if out.isEmpty { out = "Rita" }
        return out
    }

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
