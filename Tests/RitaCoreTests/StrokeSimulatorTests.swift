import Testing
@testable import RitaCore

private func blackTip(_ n: Int = 16) -> RGBAImage {
    RGBAImage(width: n, height: n, fill: (0, 0, 0, 255))
}

/// Nombre de pixels d'encre (alpha > 0) dans la colonne x.
private func inkHeight(_ img: RGBAImage, column x: Int) -> Int {
    (0..<img.height).filter { img.pixel(x: x, y: $0).3 > 0 }.count
}

@Test func factorFormula() {
    var s = BrushSettings.default
    s.options[.opacity] = .init(enabled: true, strength: 0.5, curve: .linear)
    #expect(abs(StrokeSimulator.factor(.opacity, settings: s, pressure: 0.2) - 0.6) < 1e-9)
    s.options[.opacity]!.enabled = false
    #expect(StrokeSimulator.factor(.opacity, settings: s, pressure: 0.2) == 1)
    s.options[.opacity] = nil
    #expect(StrokeSimulator.factor(.opacity, settings: s, pressure: 0.2) == 1)
}

@Test func strokeNotEmpty() {
    let out = StrokeSimulator.render(
        tip: blackTip(), settings: .default, width: 400, height: 120, background: nil)
    #expect(out.width == 400 && out.height == 120)
    #expect((0..<(400 * 120)).contains { out.pixels[4 * $0 + 3] > 0 })
}

@Test func backgroundFillsCanvas() {
    let out = StrokeSimulator.render(
        tip: blackTip(), settings: .default, width: 100, height: 60, background: (255, 255, 255, 255))
    #expect(out.pixel(x: 0, y: 0) == (255, 255, 255, 255))
}

@Test func sizeFollowsPressure() {
    var s = BrushSettings.default
    s.diameter = 40
    s.options[.size] = .init(enabled: true, strength: 1, curve: .linear)
    s.options[.opacity]!.enabled = false
    let out = StrokeSimulator.render(tip: blackTip(), settings: s, width: 400, height: 120, background: nil)
    #expect(inkHeight(out, column: 200) > inkHeight(out, column: 60))
}

@Test func deterministic() {
    var s = BrushSettings.default
    s.options[.scatter] = .init(enabled: true, strength: 1, curve: .linear)
    let a = StrokeSimulator.render(tip: blackTip(), settings: s, width: 300, height: 100, background: nil)
    let b = StrokeSimulator.render(tip: blackTip(), settings: s, width: 300, height: 100, background: nil)
    #expect(a == b)
}
