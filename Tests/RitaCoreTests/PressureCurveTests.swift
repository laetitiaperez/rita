import Testing
@testable import RitaCore

@Test func parsesAndPrints() {
    let c = PressureCurve(string: "0,0.0100507;0.407035,0.291457;1,1;")!
    #expect(c.points.count == 3)
    #expect(c.description == "0,0.010051;0.407035,0.291457;1,1;")
    #expect(PressureCurve(string: "0,0;1,1")?.description == "0,0;1,1;")
    #expect(PressureCurve(string: "0,0;1,1.5;") == nil)
    #expect(PressureCurve(string: "abc") == nil)
}
@Test func presets() {
    #expect(PressureCurve.linear.description == "0,0;1,1;")
    #expect(PressureCurve.soft.description == "0,0;0.5,0.25;1,1;")
    #expect(PressureCurve.firm.description == "0,0;0.5,0.75;1,1;")
    for c in [PressureCurve.linear, .soft, .firm] {
        let v = stride(from: 0.0, through: 1.0, by: 0.01).map(c.value(at:))
        #expect(zip(v, v.dropFirst()).allSatisfy { $0 <= $1 + 1e-9 })
    }
}
@Test func endpointsAndInterpolation() {
    let c = PressureCurve(string: "0,0.2;1,0.8;")!
    #expect(abs(c.value(at: 0) - 0.2) < 1e-9 && abs(c.value(at: 1) - 0.8) < 1e-9)
    #expect(abs(c.value(at: 0.5) - 0.5) < 1e-9)
    #expect(abs(PressureCurve.soft.value(at: 0.5) - 0.25) < 1e-9)
    #expect(c.value(at: -1) == c.value(at: 0) && c.value(at: 2) == c.value(at: 1))
}
@Test func duplicateXKeepsLast() {
    var c = PressureCurve.linear
    c.add(.init(x: 0.5, y: 0.1)); c.add(.init(x: 0.5, y: 0.9))
    #expect(c.points.map(\.y) == [0, 0.9, 1])
    let d = PressureCurve(points: [.init(x: 0, y: 0), .init(x: 0.5, y: 0.2), .init(x: 0.5, y: 0.7), .init(x: 1, y: 1)])
    #expect(d.points.map(\.y) == [0, 0.7, 1])
}
@Test func clampsAndKeepsEnds() {
    var c = PressureCurve(points: [.init(x: 0.3, y: 2), .init(x: -1, y: 0.5)])
    #expect(c.points.first!.x == 0 && c.points.last!.x == 1)
    #expect(c.points.allSatisfy { (0...1).contains($0.y) })
    c.remove(index: 0)                       // l'extrémité x = 0 ne se supprime pas
    #expect(c.points.first!.x == 0)
    c.move(index: 0, to: .init(x: 0.4, y: 0.7)) // l'extrémité ne bouge que verticalement
    #expect(c.points.first! == .init(x: 0, y: 0.7))
}
@Test func moveResortsAndMovedWins() {
    var c = PressureCurve(string: "0,0;0.3,0.3;0.6,0.6;1,1;")!
    c.move(index: 1, to: .init(x: 0.8, y: 0.2))
    #expect(c.points.map(\.x) == [0, 0.6, 0.8, 1])
    c.move(index: 1, to: .init(x: 0.8, y: 0.5))
    #expect(c.points.map(\.x) == [0, 0.8, 1] && c.points[1].y == 0.5)
    c.remove(index: 1)
    #expect(c == .linear)
}
@Test func degenerateFallsBackToLinear() {
    #expect(PressureCurve(points: []) == .linear)
    #expect(kritaNumber(0.0100507) == "0.010051" && kritaNumber(1) == "1" && kritaNumber(0) == "0")
}
