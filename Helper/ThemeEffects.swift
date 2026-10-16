//
//  ThemeEffects.swift
//  Ovra
//
//  Created by Ovra on 2/28/26.
//

import SwiftUI

/// Central resolver for the current theme's visual effects.
/// Built-in themes have default effects; custom themes store their own.
struct ThemeEffects {
    let gradient: LinearGradient
    let blurRadius: Double
    let noiseOpacity: Double
    let chromeOpacity: Double
    /// True when text and icons on the theme should be dark.
    let usesDarkText: Bool

    var foreground: Color {
        usesDarkText ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white
    }

    /// Resolve the current theme effects from AppStorage values.
    static func resolve(selectedTheme: String, customThemesData: Data) -> ThemeEffects {
        if let theme = Theme.allCases.first(where: { $0.rawValue == selectedTheme }) {
            return ThemeEffects(theme)
        }
        if let uuid = UUID(uuidString: selectedTheme),
           let matched = ThemeLibrary.decode(customThemesData).first(where: { $0.id == uuid }) {
            return ThemeEffects(matched)
        }
        return ThemeEffects(Theme.bluePurple)
    }

    /// The effects of the theme selected right now.
    static var current: ThemeEffects {
        resolve(selectedTheme: ThemeLibrary.selectedThemeID, customThemesData: ThemeLibrary.customThemesData)
    }

    init(_ theme: Theme) {
        gradient = theme.gradient
        blurRadius = 0
        noiseOpacity = 0
        chromeOpacity = 1
        usesDarkText = ThemeGradient.usesDarkText(hexes: theme.colorHexes, style: .auto)
    }

    init(_ theme: CustomTheme) {
        gradient = theme.gradient
        blurRadius = theme.blurRadius
        noiseOpacity = theme.noiseOpacity
        chromeOpacity = theme.chromeOpacity
        // A see-through theme shows the desktop, so lean on the system look.
        usesDarkText = ThemeGradient.usesDarkText(hexes: theme.colorHexes, style: theme.textStyle)
    }
}

/// Reads and writes the selected theme and the user's custom themes.
/// Storage keys are shared with the views' @AppStorage, so they update live.
enum ThemeLibrary {
    static let selectedKey = "selectedTheme"
    static let customKey = "customThemes"

    static var selectedThemeID: String {
        get { UserDefaults.standard.string(forKey: selectedKey) ?? Theme.bluePurple.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: selectedKey) }
    }

    static var customThemesData: Data {
        UserDefaults.standard.data(forKey: customKey) ?? Data()
    }

    static var customThemes: [CustomTheme] {
        get { decode(customThemesData) }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: customKey)
            }
        }
    }

    static func decode(_ data: Data) -> [CustomTheme] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([CustomTheme].self, from: data)) ?? []
    }

    /// Adds or replaces a theme (matched by id).
    static func save(_ theme: CustomTheme) {
        var themes = customThemes
        let clean = theme.sanitized()
        if let index = themes.firstIndex(where: { $0.id == clean.id }) {
            themes[index] = clean
        } else {
            themes.append(clean)
        }
        customThemes = themes
    }

    static func delete(_ theme: CustomTheme) {
        customThemes = customThemes.filter { $0.id != theme.id }
        if selectedThemeID == theme.id.uuidString {
            selectedThemeID = Theme.bluePurple.rawValue
        }
    }

    @discardableResult
    static func duplicate(_ theme: CustomTheme) -> CustomTheme {
        var copy = theme
        copy.id = UUID()
        copy.name = uniqueName(String(format: NSLocalizedString("%@ Copy", comment: ""), theme.name))
        save(copy)
        return copy
    }

    /// Adds imported themes, giving them fresh ids and non-clashing names.
    static func add(imported themes: [CustomTheme]) -> [CustomTheme] {
        var added: [CustomTheme] = []
        for theme in themes {
            var copy = theme.sanitized()
            copy.id = UUID()
            copy.name = uniqueName(copy.name)
            save(copy)
            added.append(copy)
        }
        return added
    }

    static func uniqueName(_ name: String) -> String {
        let taken = Set(customThemes.map(\.name)).union(Theme.allCases.map(\.rawValue))
        guard taken.contains(name) else { return name }
        var n = 2
        while taken.contains("\(name) \(n)") { n += 1 }
        return "\(name) \(n)"
    }
}

/// Text color that stays legible on the current theme's gradient.
enum ThemeForeground {
    static func color(for selectedTheme: String) -> Color {
        ThemeEffects.resolve(selectedTheme: selectedTheme, customThemesData: ThemeLibrary.customThemesData).foreground
    }
}

/// A white-noise texture view drawn with Canvas
struct NoiseTexture: View {
    let opacity: Double

    var body: some View {
        if opacity > 0.001 {
            Canvas { context, size in
                let step = 4
                for x in stride(from: 0, to: Int(size.width), by: step) {
                    for y in stride(from: 0, to: Int(size.height), by: step) {
                        let brightness = Double.random(in: 0...1)
                        let color = Color.white.opacity(brightness * opacity)
                        context.fill(
                            Path(CGRect(x: x, y: y, width: step, height: step)),
                            with: .color(color)
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .drawingGroup()
        }
    }
}
