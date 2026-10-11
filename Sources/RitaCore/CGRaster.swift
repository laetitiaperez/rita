import CoreGraphics

/// Aides CoreGraphics partagées : dessin dans un contexte RGBA8 prémultiplié, puis reconversion.
enum CGRaster {
    static var sRGB: CGColorSpace { CGColorSpace(name: CGColorSpace.sRGB)! }

    /// Dessine `img` dans un contexte transparent ; `setup` renvoie le rectangle de destination.
    static func draw(
        _ img: RGBAImage, width: Int, height: Int, setup: (CGContext) -> CGRect
    ) -> RGBAImage {
        var pixels = [UInt8](repeating: 0, count: 4 * width * height)
        pixels.withUnsafeMutableBytes { buf in
            guard
                let ctx = CGContext(
                    data: buf.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: 4 * width,
                    space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            ctx.interpolationQuality = .high
            let rect = setup(ctx)
            ctx.draw(ImageFile.cgImage(img), in: rect)
        }
        return unpremultiplied(pixels, width: width, height: height)
    }

    static func unpremultiplied(_ premultiplied: [UInt8], width: Int, height: Int) -> RGBAImage {
        var p = premultiplied
        for i in 0..<(width * height) {
            let a = Int(p[4 * i + 3])
            if a == 0 {
                p[4 * i] = 0; p[4 * i + 1] = 0; p[4 * i + 2] = 0
            } else if a < 255 {
                for k in 0..<3 {
                    p[4 * i + k] = UInt8(min(255, (Double(p[4 * i + k]) * 255 / Double(a)).rounded()))
                }
            }
        }
        return RGBAImage(width: width, height: height, pixels: p)
    }
}
