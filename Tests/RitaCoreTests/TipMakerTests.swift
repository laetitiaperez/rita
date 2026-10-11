import Testing
@testable import RitaCore

/// Image 20×20 blanche avec un carré noir opaque de (5,6) à (9,12) inclus.
private func square(color: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 255)) -> RGBAImage {
    var img = RGBAImage(width: 20, height: 20, fill: (255, 255, 255, 255))
    for y in 6...12 { for x in 5...9 { img.setPixel(x: x, y: y, color) } }
    return img
}

@Test func whiteBecomesTransparentAndCrops() throws {
    let t = try TipMaker.make(square(), options: .init(), mode: .mask)
    #expect(t.width == 5 + 4 && t.height == 7 + 4)
    #expect(t.pixel(x: 0, y: 0).3 == 0)
    #expect(t.pixel(x: 4, y: 5) == (0, 0, 0, 255))
}

@Test func thresholdRampSoftensEdge() throws {
    var img = RGBAImage(width: 3, height: 1, fill: (255, 255, 255, 255))
    img.setPixel(x: 0, y: 0, (237, 237, 237, 255))
    img.setPixel(x: 1, y: 0, (200, 200, 200, 255))
    var o = TipOptions(); o.autoCrop = false
    let t = try TipMaker.make(img, options: o, mode: .mask)
    let a = t.pixel(x: 0, y: 0).3
    #expect(a > 0 && a < 255)
    #expect(abs(Int(a) - 127) <= 1)
    #expect(t.pixel(x: 1, y: 0).3 == 255)
    #expect(t.pixel(x: 2, y: 0).3 == 0)
    o.threshold = 255
    let t2 = try TipMaker.make(img, options: o, mode: .mask)
    #expect(t2.pixel(x: 2, y: 0).3 == 255)
}

@Test func invert() throws {
    var o = TipOptions(); o.invert = true
    let t = try TipMaker.make(square(), options: o, mode: .mask)
    #expect(t.width == 20 && t.height == 20)
    #expect(t.pixel(x: 0, y: 0) == (0, 0, 0, 255))
    #expect(t.pixel(x: 6, y: 8).3 == 0)
}

@Test func downscalesToMaxSize() throws {
    let img = RGBAImage(width: 1000, height: 500, fill: (0, 0, 0, 255))
    let t = try TipMaker.make(img, options: .init(), mode: .mask)
    #expect(t.width == 512 && t.height == 256)
}

@Test func neverUpscales() throws {
    var o = TipOptions(); o.maxSize = 1024
    let t = try TipMaker.make(square(), options: o, mode: .mask)
    #expect(t.width == 9 && t.height == 11)
}

@Test func maskModeIsGray() throws {
    let t = try TipMaker.make(square(color: (255, 0, 0, 255)), options: .init(), mode: .mask)
    let p = t.pixel(x: 4, y: 5)
    #expect(p.0 == p.1 && p.1 == p.2)
    let c = try TipMaker.make(square(color: (255, 0, 0, 255)), options: .init(), mode: .colorImage)
    #expect(c.pixel(x: 4, y: 5) == (255, 0, 0, 255))
}

@Test func keepsExistingAlpha() throws {
    let t = try TipMaker.make(square(color: (0, 0, 0, 100)), options: .init(), mode: .mask)
    #expect(t.pixel(x: 4, y: 5).3 == 100)
}

@Test func contrastDarkensAndLightens() throws {
    var img = RGBAImage(width: 2, height: 1, fill: (100, 100, 100, 255))
    img.setPixel(x: 1, y: 0, (200, 200, 200, 255))
    var o = TipOptions(); o.autoCrop = false; o.contrast = 100
    let t = try TipMaker.make(img, options: o, mode: .colorImage)
    #expect(t.pixel(x: 0, y: 0).0 == 72)
    #expect(t.pixel(x: 1, y: 0).0 == 255)
}

@Test func emptyThrows() {
    #expect(throws: TipError.empty) {
        try TipMaker.make(RGBAImage(width: 10, height: 10, fill: (255, 255, 255, 255)),
                          options: .init(), mode: .mask)
    }
}

@Test func suggestedMode() {
    #expect(TipMaker.suggestedMode(for: square()) == .mask)
    var img = RGBAImage(width: 10, height: 10, fill: (255, 255, 255, 255))
    for x in 0..<5 { img.setPixel(x: x, y: 0, (200, 30, 30, 255)) }
    #expect(TipMaker.suggestedMode(for: img) == .colorImage)
}

@Test func rotation90() throws {
    var img = RGBAImage(width: 20, height: 20, fill: (255, 255, 255, 255))
    for y in 5..<11 { for x in 8..<10 { img.setPixel(x: x, y: y, (0, 0, 0, 255)) } }
    var o = TipOptions(); o.angle = 90
    let t = try TipMaker.make(img, options: o, mode: .mask)
    #expect(t.width == 10 && t.height == 6)
}
