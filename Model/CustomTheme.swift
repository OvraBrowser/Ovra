//
//  CustomTheme.swift
//  Ovra
//
//  Created by Kilian Balaguer on 25/06/2025.
//

import SwiftUI

/// A user-made theme. Stored as JSON in UserDefaults ("customThemes") and
/// shared as `.ovratheme` files.
struct CustomTheme: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    /// 2–4 gradient stops, first to last.
    var colorHexes: [String]
    /// CSS-style direction in degrees (135 = top-left → bottom-right).
    var angle: Double = 135
    var textStyle: ThemeTextStyle = .auto
    var blurRadius: Double = 0       // 0–30, frosted glass amount
    var noiseOpacity: Double = 0     // 0–0.3, white noise texture
    var chromeOpacity: Double = 1.0  // 0.3–1.0, gradient layer opacity (lower = more transparent)

    init(id: UUID = UUID(), name: String, colorHexes: [String], angle: Double = 135,
         textStyle: ThemeTextStyle = .auto, blurRadius: Double = 0,
         noiseOpacity: Double = 0, chromeOpacity: Double = 1.0) {
        self.id = id
        self.name = name
        self.colorHexes = colorHexes
        self.angle = angle
        self.textStyle = textStyle
        self.blurRadius = blurRadius
        self.noiseOpacity = noiseOpacity
        self.chromeOpacity = chromeOpacity
    }

    /// Starts a custom theme from a built-in one.
    init(copying theme: Theme) {
        self.init(name: theme.rawValue, colorHexes: theme.colorHexes, angle: theme.angle)
    }

    var gradient: LinearGradient {
        ThemeGradient.linear(hexes: colorHexes, angle: angle)
    }

    var hasEffects: Bool {
        blurRadius > 0 || noiseOpacity > 0 || chromeOpacity < 1.0
    }

    /// Clamps values coming from files so a bad import can't break the window.
    func sanitized() -> CustomTheme {
        var copy = self
        copy.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        if copy.name.isEmpty { copy.name = NSLocalizedString("Untitled Theme", comment: "") }
        let hexes = colorHexes.filter { hex in
            let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            return clean.count == 6 && UInt64(clean, radix: 16) != nil
        }
        copy.colorHexes = Array(hexes.prefix(4))
        if copy.colorHexes.count < 2 { copy.colorHexes = Theme.bluePurple.colorHexes }
        copy.angle = angle.truncatingRemainder(dividingBy: 360)
        copy.blurRadius = min(max(blurRadius, 0), 30)
        copy.noiseOpacity = min(max(noiseOpacity, 0), 0.3)
        copy.chromeOpacity = min(max(chromeOpacity, 0.3), 1)
        return copy
    }

    // MARK: Codable (reads themes saved before colour stops existed)

    private enum CodingKeys: String, CodingKey {
        case id, name, colorHexes, angle, textStyle, blurRadius, noiseOpacity, chromeOpacity
        case color1Hex, color2Hex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        if let hexes = try c.decodeIfPresent([String].self, forKey: .colorHexes) {
            colorHexes = hexes
        } else {
            colorHexes = [
                try c.decodeIfPresent(String.self, forKey: .color1Hex) ?? "#667EEA",
                try c.decodeIfPresent(String.self, forKey: .color2Hex) ?? "#764BA2"
            ]
        }
        angle = try c.decodeIfPresent(Double.self, forKey: .angle) ?? 135
        textStyle = (try? c.decodeIfPresent(ThemeTextStyle.self, forKey: .textStyle)) ?? .auto
        blurRadius = try c.decodeIfPresent(Double.self, forKey: .blurRadius) ?? 0
        noiseOpacity = try c.decodeIfPresent(Double.self, forKey: .noiseOpacity) ?? 0
        chromeOpacity = try c.decodeIfPresent(Double.self, forKey: .chromeOpacity) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(colorHexes, forKey: .colorHexes)
        try c.encode(angle, forKey: .angle)
        try c.encode(textStyle, forKey: .textStyle)
        try c.encode(blurRadius, forKey: .blurRadius)
        try c.encode(noiseOpacity, forKey: .noiseOpacity)
        try c.encode(chromeOpacity, forKey: .chromeOpacity)
        // Kept so older Ovra builds can still read the theme.
        try c.encode(colorHexes.first ?? "#667EEA", forKey: .color1Hex)
        try c.encode(colorHexes.last ?? "#764BA2", forKey: .color2Hex)
    }
}
