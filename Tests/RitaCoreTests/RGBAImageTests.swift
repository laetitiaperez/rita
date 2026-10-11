import Testing
@testable import RitaCore

@Test func pixelRoundTrip() {
    var img = RGBAImage(width: 3, height: 2, fill: (1, 2, 3, 4))
    img.setPixel(x: 2, y: 1, (9, 8, 7, 6))
    let p = img.pixel(x: 2, y: 1)
    #expect(p.0 == 9)
    #expect(p.1 == 8)
    #expect(p.2 == 7)
    #expect(p.3 == 6)
    #expect(img.pixels.count == 24)
}

