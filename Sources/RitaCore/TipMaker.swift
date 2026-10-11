import CoreGraphics
import Foundation

public struct TipOptions: Equatable, Codable, Sendable {
    public var threshold: Int = 245
    public var contrast: Int = 0
    public var invert = false
    public var autoCrop = true
    public var maxSize: Int = 512
    public var angle: Double = 0

    public init() {}
}

public enum TipError: Error, Equatable { case empty }

public enum TipMaker {
    private static let margin = 2
    private static let rampWidth = 16.0

    public static func make(_ src: RGBAImage, options: TipOptions, mode: TipMode) throws -> RGBAImage {
        var img = prepared(src, options: options, mode: mode)
        guard hasVisiblePixel(img) else { throw TipError.empty }

        let angle = options.angle.truncatingRemainder(dividingBy: 360)
        if angle != 0 { img = rotated(img, degrees: angle) }
        if options.autoCrop {
            guard let cropped = cropped(img) else { throw TipError.empty }
            img = cropped
        } else if !hasVisiblePixel(img) {
            throw TipError.empty
        }
        let longest = max(img.width, img.height)
        if longest > options.maxSize, options.maxSize > 0 {
            let scale = Double(options.maxSize) / Double(longest)
            img = resized(
                img, width: max(1, Int((Double(img.width) * scale).rounded())),
                height: max(1, Int((Double(img.height) * scale).rounded())))
        }
        return img
    }

    /// Image couleur si plus de 2 % des pixels opaques ont une saturation > 0,15.
    public static func suggestedMode(for image: RGBAImage) -> TipMode {
        var opaque = 0, colored = 0
        for i in 0..<(image.width * image.height) where image.pixels[4 * i + 3] > 128 {
            opaque += 1
            let r = Double(image.pixels[4 * i]), g = Double(image.pixels[4 * i + 1])
            let b = Double(image.pixels[4 * i + 2])
            let hi = max(r, g, b), lo = min(r, g, b)
            if hi > 0, (hi - lo) / hi > 0.15 { colored += 1 }
        }
        return opaque > 0 && Double(colored) > 0.02 * Double(opaque) ? .colorImage : .mask
    }

    // MARK: - Contraste, inversion, seuil, niveaux de gris

    private static func prepared(_ src: RGBAImage, options: TipOptions, mode: TipMode) -> RGBAImage {
        var out = src
        let factor = 1 + Double(options.contrast) / 100
        let threshold = Double(options.threshold)
        let thresholdOn = options.threshold < 255
        for i in 0..<(src.width * src.height) {
            var c = (0..<3).map { Double(src.pixels[4 * i + $0]) }
            if options.contrast != 0 {
                c = c.map { min(255, max(0, ($0 - 128) * factor + 128)).rounded() }
            }
            if options.invert { c = c.map { 255 - $0 } }
            let lum = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
            var alpha = Int(src.pixels[4 * i + 3])
            if thresholdOn {
                let ramp = 255 * (threshold - lum) / rampWidth
                alpha = min(alpha, Int(min(255, max(0, ramp))))
            }
            if mode == .mask {
                let g = UInt8(min(255, max(0, lum.rounded())))
                c = [Double(g), Double(g), Double(g)]
            }
            for k in 0..<3 { out.pixels[4 * i + k] = UInt8(c[k]) }
            out.pixels[4 * i + 3] = UInt8(alpha)
        }
        return out
    }

    // MARK: - Recadrage

    private static func hasVisiblePixel(_ img: RGBAImage) -> Bool {
        for i in 0..<(img.width * img.height) where img.pixels[4 * i + 3] > 0 { return true }
        return false
    }

    private static func cropped(_ img: RGBAImage) -> RGBAImage? {
        var minX = img.width, minY = img.height, maxX = -1, maxY = -1
        for y in 0..<img.height {
            for x in 0..<img.width where img.pixels[4 * (y * img.width + x) + 3] > 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        let x0 = max(0, minX - margin), y0 = max(0, minY - margin)
        let x1 = min(img.width - 1, maxX + margin), y1 = min(img.height - 1, maxY + margin)
        let w = x1 - x0 + 1, h = y1 - y0 + 1
        var out = RGBAImage(width: w, height: h, fill: (0, 0, 0, 0))
        for y in 0..<h {
            for x in 0..<w { out.setPixel(x: x, y: y, img.pixel(x: x0 + x, y: y0 + y)) }
        }
        return out
    }

    // MARK: - CoreGraphics (rotation, réduction)

    private static func rotated(_ img: RGBAImage, degrees: Double) -> RGBAImage {
        let rad = degrees * .pi / 180
        let c = abs(cos(rad)), s = abs(sin(rad))
        let w = Double(img.width), h = Double(img.height)
        // Arrondi à 1e-6 pour éviter qu'un 90° exact ne gagne un pixel (cos ≈ 6e-17).
        let newW = max(1, Int((w * c + h * s - 1e-6).rounded(.up)))
        let newH = max(1, Int((w * s + h * c - 1e-6).rounded(.up)))
        return CGRaster.draw(img, width: newW, height: newH) { ctx in
            ctx.translateBy(x: Double(newW) / 2, y: Double(newH) / 2)
            ctx.rotate(by: -rad)  // sens horaire à l'écran (origine en bas pour CG)
            ctx.translateBy(x: -w / 2, y: -h / 2)
            return CGRect(x: 0, y: 0, width: w, height: h)
        }
    }

    private static func resized(_ img: RGBAImage, width: Int, height: Int) -> RGBAImage {
        CGRaster.draw(img, width: width, height: height) { _ in
            CGRect(x: 0, y: 0, width: width, height: height)
        }
    }
}
