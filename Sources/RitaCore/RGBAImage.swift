/// Image RGBA8 non prémultipliée, sRGB, origine en haut à gauche, rangée par rangée.
public struct RGBAImage: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == 4 * width * height)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public init(width: Int, height: Int, fill: (UInt8, UInt8, UInt8, UInt8)) {
        var pixels = [UInt8](repeating: 0, count: 4 * width * height)
        for i in 0..<(width * height) {
            pixels[4 * i] = fill.0
            pixels[4 * i + 1] = fill.1
            pixels[4 * i + 2] = fill.2
            pixels[4 * i + 3] = fill.3
        }
        self.init(width: width, height: height, pixels: pixels)
    }

    public func pixel(x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let i = 4 * (y * width + x)
        return (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
    }

    public mutating func setPixel(x: Int, y: Int, _ p: (UInt8, UInt8, UInt8, UInt8)) {
        let i = 4 * (y * width + x)
        pixels[i] = p.0
        pixels[i + 1] = p.1
        pixels[i + 2] = p.2
        pixels[i + 3] = p.3
    }
}
