import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import RitaCore

private func encode(_ cg: CGImage, type: UTType, properties: [CFString: Any]? = nil) -> Data {
    let out = NSMutableData()
    let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, cg, properties as CFDictionary?)
    precondition(CGImageDestinationFinalize(dest))
    return out as Data
}

private func rgbContext(width: Int, height: Int, bits: Int = 8, alpha: CGImageAlphaInfo) -> CGContext {
    CGContext(
        data: nil, width: width, height: height, bitsPerComponent: bits, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue)!
}

@Suite struct ImageFileTests {
    @Test func pngRoundTrip() throws {
        var img = RGBAImage(width: 2, height: 1, fill: (0, 0, 0, 0))
        img.setPixel(x: 0, y: 0, (200, 100, 50, 128))
        img.setPixel(x: 1, y: 0, (10, 20, 30, 0))
        let back = try ImageFile.load(data: ImageFile.pngData(img))
        #expect(back.width == 2 && back.height == 1)
        let p = back.pixel(x: 0, y: 0)
        #expect(abs(Int(p.0) - 200) <= 1)
        #expect(abs(Int(p.1) - 100) <= 1)
        #expect(abs(Int(p.2) - 50) <= 1)
        #expect(p.3 == 128)
        #expect(back.pixel(x: 1, y: 0).3 == 0)
    }

    @Test func exifOrientation() throws {
        let ctx = rgbContext(width: 2, height: 1, alpha: .noneSkipLast)
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
        let data = encode(
            ctx.makeImage()!, type: .jpeg,
            properties: [
                kCGImagePropertyOrientation: 6,
                kCGImageDestinationLossyCompressionQuality: 1.0,
            ])
        let img = try ImageFile.load(data: data)
        #expect(img.width == 1 && img.height == 2)
        // Orientation 6 : rotation 90° horaire à l'affichage ; le pixel gauche (rouge) passe en haut.
        let p = img.pixel(x: 0, y: 0)
        #expect(Int(p.0) >= 245 && Int(p.1) <= 10 && Int(p.2) <= 10)
        let q = img.pixel(x: 0, y: 1)
        #expect(Int(q.2) >= 245 && Int(q.0) <= 10)
    }

    @Test func grayscaleAnd16Bit() throws {
        let gray = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        gray.setFillColor(gray: 128.0 / 255.0, alpha: 1)
        gray.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let g = try ImageFile.load(data: encode(gray.makeImage()!, type: .png))
        let p = g.pixel(x: 0, y: 0)
        #expect(abs(Int(p.0) - 128) <= 2 && abs(Int(p.1) - 128) <= 2 && abs(Int(p.2) - 128) <= 2)
        #expect(p.3 == 255)

        let c16 = rgbContext(width: 1, height: 1, bits: 16, alpha: .premultipliedLast)
        c16.setFillColor(CGColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        c16.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let s = try ImageFile.load(data: encode(c16.makeImage()!, type: .png))
        #expect(s.width == 1)
    }

    @Test func garbageThrows() {
        #expect(throws: ImageFileError.self) {
            try ImageFile.load(data: Data("pas une image".utf8))
        }
    }

    @Test func loadDownscales() throws {
        let big = RGBAImage(width: 4000, height: 1000, fill: (10, 20, 30, 255))
        let img = try ImageFile.load(data: ImageFile.pngData(big), maxDimension: 2048)
        #expect(img.width == 2048 && img.height == 512)
        let small = try ImageFile.load(data: ImageFile.pngData(big), maxDimension: 8000)
        #expect(small.width == 4000)   // jamais d'agrandissement
    }
}
