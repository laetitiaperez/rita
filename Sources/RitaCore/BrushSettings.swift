import Foundation

/// Façon dont Krita utilise l'image de la pointe.
public enum TipMode: String, Codable, CaseIterable, Sendable {
    case mask, colorImage, lightnessMap
}

/// Réglage de la pression pour une option de la brush.
public struct PressureOption: Equatable, Codable, Sendable {
    public var enabled: Bool
    public var strength: Double
    public var curve: PressureCurve
    public init(enabled: Bool, strength: Double, curve: PressureCurve) {
        self.enabled = enabled; self.strength = strength; self.curve = curve
    }
}

public enum PressureKind: String, Codable, CaseIterable, Sendable, CodingKeyRepresentable {
    case size, opacity, flow, rotation, scatter, spacing

    public var kritaKey: String {
        switch self {
        case .size: "Size"
        case .opacity: "Opacity"
        case .flow: "Flow"
        case .rotation: "Rotation"
        case .scatter: "Scatter"
        case .spacing: "Spacing"
        }
    }

    public var label: String {
        switch self {
        case .size: "Taille"
        case .opacity: "Opacité"
        case .flow: "Flux"
        case .rotation: "Rotation"
        case .scatter: "Dispersion"
        case .spacing: "Espacement"
        }
    }
}

public struct BrushSettings: Equatable, Codable, Sendable {
    public var name: String
    public var tipMode: TipMode
    public var diameter: Double
    public var spacing: Double
    public var options: [PressureKind: PressureOption]

    public init(name: String, tipMode: TipMode, diameter: Double, spacing: Double,
                options: [PressureKind: PressureOption]) {
        self.name = name; self.tipMode = tipMode; self.diameter = diameter
        self.spacing = spacing; self.options = options
    }

    public static let `default` = BrushSettings(
        name: "Rita", tipMode: .mask, diameter: 40, spacing: 0.1,
        options: Dictionary(uniqueKeysWithValues: PressureKind.allCases.map {
            ($0, PressureOption(enabled: $0 == .size || $0 == .opacity, strength: 1, curve: .linear))
        }))
}
