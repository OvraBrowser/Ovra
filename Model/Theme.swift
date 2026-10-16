import SwiftUI

/// Built-in themes. Raw values are stored in `selectedTheme`, so never rename them.
enum Theme: String, CaseIterable, Identifiable {
    case bluePurple = "Aurora"
    case velvetDusk = "Velvet Dusk"
    case midnight = "Midnight Blue"
    case forestBloom = "Forest Bloom"
    case ocean = "Deep Ocean"
    case tealPink = "Neon Sunset"
    case redOrange = "Crimson Heat"
    case greenYellow = "Solar Flare"
    case coral = "Coral Reef"
    case rose = "Rosé"
    case icyMist = "Icy Mist"
    case graphite = "Graphite"

    var id: String { rawValue }

    /// Gradient stops, first to last.
    var colorHexes: [String] {
        switch self {
        case .bluePurple:  return ["#5A68D6", "#5E4BB8", "#5A3590"]
        case .velvetDusk:  return ["#84406F", "#632E62", "#3F1F4A"]
        case .midnight:    return ["#2A3F7A", "#1F2D5E", "#141D3D"]
        case .forestBloom: return ["#2F6B55", "#25594A", "#1B3E36"]
        case .ocean:       return ["#1C7C9C", "#155E86", "#0E3B5C"]
        case .tealPink:    return ["#2BAF8F", "#7A6FC8", "#D35FB0"]
        case .redOrange:   return ["#D9434F", "#E5683A", "#F09819"]
        case .greenYellow: return ["#F2994A", "#F2B544", "#F2C94C"]
        case .coral:       return ["#FF7E5F", "#FD9A6E", "#FEB47B"]
        case .rose:        return ["#F3B6C2", "#F7CDD5", "#FDE6EA"]
        case .icyMist:     return ["#E0EAFC", "#D6E3F6", "#CFDEF3"]
        case .graphite:    return ["#4A4A52", "#2E2E34", "#1C1C20"]
        }
    }

    /// CSS-style direction in degrees (135 = top-left → bottom-right).
    var angle: Double {
        switch self {
        case .icyMist, .rose: return 180
        default: return 125
        }
    }

    var gradient: LinearGradient {
        ThemeGradient.linear(hexes: colorHexes, angle: angle)
    }
}

/// Which text colour sits on top of the theme.
enum ThemeTextStyle: String, Codable, CaseIterable, Identifiable {
    case auto, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return NSLocalizedString("Automatic", comment: "")
        case .light: return NSLocalizedString("Light Text", comment: "")
        case .dark: return NSLocalizedString("Dark Text", comment: "")
        }
    }
}

enum ThemeGradient {
    static func linear(hexes: [String], angle: Double) -> LinearGradient {
        let colors = (hexes.isEmpty ? Theme.bluePurple.colorHexes : hexes).map { Color(hex: $0) }
        let (start, end) = points(for: angle)
        return LinearGradient(colors: colors, startPoint: start, endPoint: end)
    }

    /// Converts a CSS angle (0 = to top, 90 = to right) into SwiftUI unit points.
    static func points(for angle: Double) -> (UnitPoint, UnitPoint) {
        let radians = (angle - 90) * .pi / 180
        let dx = cos(radians) * 0.5
        let dy = sin(radians) * 0.5
        return (UnitPoint(x: 0.5 - dx, y: 0.5 - dy), UnitPoint(x: 0.5 + dx, y: 0.5 + dy))
    }

    /// Average relative luminance (0–1) of the stops.
    static func luminance(of hexes: [String]) -> Double {
        let values = hexes.compactMap { hex -> Double? in
            let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            guard clean.count == 6, let int = UInt64(clean, radix: 16) else { return nil }
            func channel(_ v: UInt64) -> Double {
                let c = Double(v) / 255
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel((int >> 16) & 0xFF) + 0.7152 * channel((int >> 8) & 0xFF) + 0.0722 * channel(int & 0xFF)
        }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    static func usesDarkText(hexes: [String], style: ThemeTextStyle) -> Bool {
        switch style {
        case .light: return false
        case .dark: return true
        case .auto: return luminance(of: hexes) > 0.45
        }
    }
}
