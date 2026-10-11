import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageFileError: Error { case unreadable }

public enum ImageFile {
    public static func load(contentsOf url: URL, maxDimension: Int? = nil) throws -> RGBAImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageFileError.unreadable
        }
        return try decode(source, maxDimension: maxDimension)
    }

    public static func load(data: Data, maxDimension: Int? = nil) throws -> RGBAImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageFileError.unreadable
        }
        return try decode(source, maxDimension: maxDimension)
    }

    /// PNG non prémultiplié (alpha droit).
    public static func pngData(_ image: RGBAImage) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil)
        else { throw ImageFileError.unreadable }
        CGImageDestinationAddImage(destination, cgImage(image), nil)
        guard CGImageDestinationFinalize(destination) else { throw ImageFileError.unreadable }
        return output as Data
    }

    /// CGImage sRGB, alpha droit (`.last`), prêt à être dessiné.
    public static func cgImage(_ image: RGBAImage) -> CGImage {
        let provider = CGDataProvider(data: Data(image.pixels) as CFData)!
        return CGImage(
            width: image.width, height: image.height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4 * image.width,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent)!
    }

    private static func decode(_ source: CGImageSource, maxDimension: Int?) throws -> RGBAImage {
        guard CGImageSourceGetCount(source) > 0,
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let w = props[kCGImagePropertyPixelWidth] as? Int,
            let h = props[kCGImagePropertyPixelHeight] as? Int,
            w > 0, h > 0
        else { throw ImageFileError.unreadable }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: min(max(w, h), maxDimension ?? max(w, h)),
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
            cg.width > 0, cg.height > 0
        else { throw ImageFileError.unreadable }

        let width = cg.width
        let height = cg.height
        var pixels = [UInt8](repeating: 0, count: 4 * width * height)
        let drawn = pixels.withUnsafeMutableBytes { buf -> Bool in
            guard
                let ctx = CGContext(
                    data: buf.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: 4 * width,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw ImageFileError.unreadable }

        for i in 0..<(width * height) {
            let a = Int(pixels[4 * i + 3])
            if a == 0 {
                pixels[4 * i] = 0; pixels[4 * i + 1] = 0; pixels[4 * i + 2] = 0
            } else if a < 255 {
                for c in 0..<3 {
                    let v = (Double(pixels[4 * i + c]) * 255.0 / Double(a)).rounded()
                    pixels[4 * i + c] = UInt8(min(255.0, v))
                }
            }
        }
        return RGBAImage(width: width, height: height, pixels: pixels)
    }
}
