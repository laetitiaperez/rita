import Foundation

/// Nombre au format Krita : 6 décimales au plus, sans zéros ni point finaux (`0.010051`, `1`, `0`).
internal func kritaNumber(_ v: Double) -> String {
    var s = String(format: "%.6f", v)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    if s == "-0" { s = "0" }
    return s
}

/// Courbe de pression : points dans [0,1], triés par x, avec les extrémités x = 0 et x = 1.
public struct PressureCurve: Equatable, Codable, Sendable, CustomStringConvertible {
    public struct Point: Equatable, Codable, Sendable {
        public var x: Double
        public var y: Double
        public init(x: Double, y: Double) { self.x = x; self.y = y }
    }

    public private(set) var points: [Point] {
        didSet { second = Self.secondDerivatives(points) }
    }
    /// Dérivées secondes de la spline naturelle, calculées à chaque modification des points.
    private var second: [Double]

    private enum CodingKeys: String, CodingKey { case points }

    public init(points: [Point]) {
        let n = Self.normalise(points)
        self.points = n
        self.second = Self.secondDerivatives(n)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(points: try c.decode([Point].self, forKey: .points))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(points, forKey: .points)
    }

    public static func == (a: PressureCurve, b: PressureCurve) -> Bool { a.points == b.points }

    public init?(string: String) {
        var pts: [Point] = []
        for part in string.split(separator: ";", omittingEmptySubsequences: true) {
            let xy = part.split(separator: ",", omittingEmptySubsequences: false)
            guard xy.count == 2,
                  let x = Double(xy[0].trimmingCharacters(in: .whitespaces)),
                  let y = Double(xy[1].trimmingCharacters(in: .whitespaces)),
                  x.isFinite, y.isFinite,
                  (0...1).contains(x), (0...1).contains(y) else { return nil }
            pts.append(Point(x: x, y: y))
        }
        guard !pts.isEmpty else { return nil }
        self.init(points: pts)
    }

    public var description: String {
        points.map { "\(kritaNumber($0.x)),\(kritaNumber($0.y));" }.joined()
    }

    public static let linear = PressureCurve(points: [.init(x: 0, y: 0), .init(x: 1, y: 1)])
    public static let soft = PressureCurve(points: [.init(x: 0, y: 0), .init(x: 0.5, y: 0.25), .init(x: 1, y: 1)])
    public static let firm = PressureCurve(points: [.init(x: 0, y: 0), .init(x: 0.5, y: 0.75), .init(x: 1, y: 1)])

    // MARK: Édition

    /// Ajoute un point ; à x égal, le dernier ajouté remplace l'autre.
    public mutating func add(_ p: Point) {
        points = Self.normalise(points + [p])
    }

    /// Déplace un point. Les extrémités ne bougent que verticalement ; les autres points
    /// sont re-triés et, sur un x déjà occupé, le point déplacé l'emporte.
    public mutating func move(index: Int, to p: Point) {
        guard points.indices.contains(index) else { return }
        if index == 0 || index == points.count - 1 {
            points[index].y = min(max(p.y, 0), 1)
        } else {
            var pts = points
            pts.remove(at: index)
            pts.append(p)
            points = Self.normalise(pts)
        }
    }

    /// Supprime un point ; les extrémités ne se suppriment pas.
    public mutating func remove(index: Int) {
        guard points.indices.contains(index), index != 0, index != points.count - 1 else { return }
        points.remove(at: index)
    }

    // MARK: Évaluation

    /// Spline cubique naturelle (comme `KisCubicSpline`), bornée à [0,1].
    public func value(at p: Double) -> Double {
        let n = points.count
        let x = min(max(p, points[0].x), points[n - 1].x)
        var i = 0
        while i < n - 2 && x > points[i + 1].x { i += 1 }
        let x0 = points[i].x, x1 = points[i + 1].x
        let h = x1 - x0
        guard h > 0 else { return min(max(points[i].y, 0), 1) }
        let a = (x1 - x) / h, b = (x - x0) / h
        let y = a * points[i].y + b * points[i + 1].y
            + ((a * a * a - a) * second[i] + (b * b * b - b) * second[i + 1]) * h * h / 6
        return min(max(y, 0), 1)
    }

    // MARK: Internes

    private static func normalise(_ input: [Point]) -> [Point] {
        var byX: [Double: Double] = [:]
        for p in input where p.x.isFinite && p.y.isFinite {
            byX[min(max(p.x, 0), 1)] = min(max(p.y, 0), 1)   // le dernier gagne
        }
        var pts = byX.map { Point(x: $0.key, y: $0.value) }.sorted { $0.x < $1.x }
        guard let first = pts.first, let last = pts.last else {
            return [.init(x: 0, y: 0), .init(x: 1, y: 1)]
        }
        if first.x > 0 { pts.insert(Point(x: 0, y: first.y), at: 0) }
        if last.x < 1 { pts.append(Point(x: 1, y: last.y)) }
        return pts
    }

    private static func secondDerivatives(_ pts: [Point]) -> [Double] {
        let n = pts.count
        var y2 = [Double](repeating: 0, count: n)
        guard n > 2 else { return y2 }
        var u = [Double](repeating: 0, count: n)
        for i in 1..<(n - 1) {
            let sig = (pts[i].x - pts[i - 1].x) / (pts[i + 1].x - pts[i - 1].x)
            let pv = sig * y2[i - 1] + 2
            y2[i] = (sig - 1) / pv
            let d = (pts[i + 1].y - pts[i].y) / (pts[i + 1].x - pts[i].x)
                - (pts[i].y - pts[i - 1].y) / (pts[i].x - pts[i - 1].x)
            u[i] = (6 * d / (pts[i + 1].x - pts[i - 1].x) - sig * u[i - 1]) / pv
        }
        for k in stride(from: n - 2, through: 0, by: -1) {
            y2[k] = y2[k] * y2[k + 1] + u[k]
        }
        return y2
    }
}
