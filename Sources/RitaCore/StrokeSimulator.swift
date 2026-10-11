import CoreGraphics
import Foundation

/// Simule un trait (une période de sinusoïde, pression 0 → 1 → 0) pour l'aperçu.
public enum StrokeSimulator {
    /// f(X) = 1 − force × (1 − courbe(p)) si l'option est activée, 1 sinon (ou si absente).
    public static func factor(_ kind: PressureKind, settings: BrushSettings, pressure: Double) -> Double {
        guard let o = settings.options[kind], o.enabled else { return 1 }
        return 1 - o.strength * (1 - o.curve.value(at: pressure))
    }

    public static func render(
        tip: RGBAImage, settings: BrushSettings, width: Int, height: Int,
        background: (UInt8, UInt8, UInt8, UInt8)?
    ) -> RGBAImage {
        var pixels = [UInt8](repeating: 0, count: 4 * width * height)
        if let bg = background {
            let a = Double(bg.3) / 255
            let pm = [bg.0, bg.1, bg.2].map { UInt8((Double($0) * a).rounded()) }
            for i in 0..<(width * height) {
                pixels[4 * i] = pm[0]; pixels[4 * i + 1] = pm[1]; pixels[4 * i + 2] = pm[2]
                pixels[4 * i + 3] = bg.3
            }
        }
        pixels.withUnsafeMutableBytes { buf in
            guard
                let ctx = CGContext(
                    data: buf.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: 4 * width,
                    space: CGRaster.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            ctx.interpolationQuality = .high
            // Origine en haut à gauche.
            ctx.translateBy(x: 0, y: Double(height))
            ctx.scaleBy(x: 1, y: -1)
            stroke(into: ctx, tip: tinted(tip, mode: settings.tipMode), settings: settings,
                   width: Double(width), height: Double(height))
        }
        return CGRaster.unpremultiplied(pixels, width: width, height: height)
    }

    // MARK: - Interne

    private static func stroke(
        into ctx: CGContext, tip: CGImage?, settings: BrushSettings, width: Double, height: Double
    ) {
        guard let tip, width > 0, height > 0 else { return }
        let baseDiameter = min(settings.diameter, height * 0.4)
        let longest = Double(max(tip.width, tip.height))
        guard baseDiameter > 0, longest > 0 else { return }

        let x0 = width * 0.1, length = width * 0.8
        let amplitude = height * 0.25, midY = height / 2
        func point(_ t: Double) -> (x: Double, y: Double) {
            (x0 + length * t, midY + amplitude * sin(2 * .pi * t))
        }
        // Longueur de la courbe, pour avancer à pas constants.
        let samples = 400
        var cumulative = [0.0]
        var prev = point(0)
        for i in 1...samples {
            let p = point(Double(i) / Double(samples))
            cumulative.append(cumulative[i - 1] + hypot(p.x - prev.x, p.y - prev.y))
            prev = p
        }
        let total = cumulative[samples]
        func tAt(distance d: Double) -> Double {
            var lo = 0, hi = samples
            while hi - lo > 1 {
                let mid = (lo + hi) / 2
                if cumulative[mid] <= d { lo = mid } else { hi = mid }
            }
            let span = cumulative[hi] - cumulative[lo]
            let frac = span > 0 ? (d - cumulative[lo]) / span : 0
            return (Double(lo) + frac) / Double(samples)
        }

        var rng = SplitMix64(seed: 42)
        var distance = 0.0
        while distance <= total {
            let t = tAt(distance: distance)
            let pressure = 1 - abs(2 * t - 1)
            let f = { (k: PressureKind) in factor(k, settings: settings, pressure: pressure) }

            let diameter = baseDiameter * f(.size)
            let scatterOn = settings.options[.scatter]?.enabled ?? false
            let jitter = rng.nextUnit() * 2 - 1  // toujours tiré : séquence stable
            var (px, py) = point(t)
            if scatterOn, diameter > 0 {
                // Décalage perpendiculaire à la tangente.
                let a = point(max(0, t - 0.001)), b = point(min(1, t + 0.001))
                let len = max(hypot(b.x - a.x, b.y - a.y), 1e-9)
                let offset = jitter * diameter * f(.scatter)
                px += -(b.y - a.y) / len * offset
                py += (b.x - a.x) / len * offset
            }
            if diameter > 0 {
                let scale = diameter / longest
                let w = Double(tip.width) * scale, h = Double(tip.height) * scale
                ctx.saveGState()
                ctx.setAlpha(min(1, max(0, f(.opacity) * f(.flow))))
                ctx.translateBy(x: px, y: py)
                ctx.rotate(by: 2 * .pi * f(.rotation))
                ctx.scaleBy(x: 1, y: -1)  // le CGImage se dessine à l'endroit
                ctx.draw(tip, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                ctx.restoreGState()
            }
            distance += max(1, settings.spacing * diameter * f(.spacing))
        }
    }

    /// Empreinte teintée : noire pour Masque et Carte de luminosité, couleurs de la pointe pour Image couleur.
    private static func tinted(_ tip: RGBAImage, mode: TipMode) -> CGImage? {
        guard tip.width > 0, tip.height > 0 else { return nil }
        var out = tip
        if mode != .colorImage {
            for i in 0..<(tip.width * tip.height) {
                var a = Double(tip.pixels[4 * i + 3])
                if mode == .mask {
                    let lum = 0.2126 * Double(tip.pixels[4 * i]) + 0.7152 * Double(tip.pixels[4 * i + 1])
                        + 0.0722 * Double(tip.pixels[4 * i + 2])
                    a *= 1 - lum / 255
                }
                out.pixels[4 * i] = 0; out.pixels[4 * i + 1] = 0; out.pixels[4 * i + 2] = 0
                out.pixels[4 * i + 3] = UInt8(min(255, max(0, a.rounded())))
            }
        }
        return ImageFile.cgImage(out)
    }
}

/// Générateur pseudo-aléatoire déterministe.
struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// Valeur dans [0, 1).
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
