//
//  ThemeEditorView.swift
//  Ovra
//
//  Sheet for creating or editing a custom theme, with a live preview.
//

import SwiftUI

struct ThemeEditorView: View {
    let isNew: Bool
    let onSave: (CustomTheme) -> Void
    let onCancel: () -> Void

    @State private var theme: CustomTheme
    @State private var colors: [Color]

    init(theme: CustomTheme, isNew: Bool, onSave: @escaping (CustomTheme) -> Void, onCancel: @escaping () -> Void) {
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
        _theme = State(initialValue: theme)
        _colors = State(initialValue: theme.colorHexes.map { Color(hex: $0) })
    }

    /// The theme with the colour pickers' current values.
    private var draft: CustomTheme {
        var copy = theme
        copy.colorHexes = colors.map { $0.toHex() }
        return copy
    }

    private var canSave: Bool {
        !theme.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private let directions: [(angle: Double, symbol: String, label: String)] = [
        (315, "arrow.up.left", "Up left"), (0, "arrow.up", "Up"), (45, "arrow.up.right", "Up right"),
        (270, "arrow.left", "Left"), (90, "arrow.right", "Right"),
        (225, "arrow.down.left", "Down left"), (180, "arrow.down", "Down"), (135, "arrow.down.right", "Down right")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNew ? NSLocalizedString("New Theme", comment: "") : NSLocalizedString("Edit Theme", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ThemePreview(effects: ThemeEffects(draft))
                        .frame(height: 200)
                        .animation(.easeInOut(duration: 0.15), value: draft)

                    SettingsGroup {
                        SettingsItem(title: NSLocalizedString("Name", comment: "")) {
                            TextField(NSLocalizedString("Theme name", comment: ""), text: $theme.name)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                        }
                    }

                    // Colours
                    SettingsGroup(title: NSLocalizedString("Colors", comment: "")) {
                        SettingsItem(
                            title: NSLocalizedString("Gradient", comment: ""),
                            subtitle: NSLocalizedString("Two to four colors, first to last.", comment: "")
                        ) {
                            HStack(spacing: 8) {
                                ForEach(colors.indices, id: \.self) { index in
                                    ColorPicker("", selection: $colors[index], supportsOpacity: false)
                                        .labelsHidden()
                                        .accessibilityLabel(String(format: NSLocalizedString("Color %d", comment: ""), index + 1))
                                }
                                Button {
                                    withAnimation { _ = colors.popLast() }
                                } label: {
                                    Image(systemName: "minus")
                                        .frame(width: 22, height: 22)
                                }
                                .buttonStyle(SettingsPillButtonStyle())
                                .disabled(colors.count <= 2)
                                .accessibilityLabel(NSLocalizedString("Remove color", comment: ""))
                                Button {
                                    withAnimation { colors.append(colors.last ?? .white) }
                                } label: {
                                    Image(systemName: "plus")
                                        .frame(width: 22, height: 22)
                                }
                                .buttonStyle(SettingsPillButtonStyle())
                                .disabled(colors.count >= 4)
                                .accessibilityLabel(NSLocalizedString("Add color", comment: ""))
                            }
                        }
                        SettingsDivider()
                        SettingsItem(title: NSLocalizedString("Direction", comment: "")) {
                            HStack(spacing: 4) {
                                ForEach(directions, id: \.angle) { direction in
                                    Button {
                                        theme.angle = direction.angle
                                    } label: {
                                        Image(systemName: direction.symbol)
                                            .font(.system(size: 11, weight: .semibold))
                                            .frame(width: 26, height: 26)
                                            .foregroundColor(isAngle(direction.angle) ? .white : Color("UIText"))
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(isAngle(direction.angle) ? Color.settingsAccent : Color("UIText").opacity(0.07))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(direction.label)
                                }
                            }
                        }
                        SettingsDivider()
                        SettingsItem(title: NSLocalizedString("Text", comment: ""),
                                     subtitle: NSLocalizedString("Automatic picks light or dark text from your colors.", comment: "")) {
                            Picker(NSLocalizedString("Text", comment: ""), selection: $theme.textStyle) {
                                ForEach(ThemeTextStyle.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .fixedSize()
                        }
                    } accessory: {
                        Button {
                            shuffle()
                        } label: {
                            Label(NSLocalizedString("Shuffle", comment: ""), systemImage: "shuffle")
                        }
                        .buttonStyle(SettingsPillButtonStyle())
                    }

                    // Effects
                    SettingsGroup(
                        title: NSLocalizedString("Effects", comment: ""),
                        footer: NSLocalizedString("Lower opacity lets your desktop show through the window.", comment: "")
                    ) {
                        slider(NSLocalizedString("Frosted glass", comment: ""), value: $theme.blurRadius, range: 0...30) {
                            String(format: "%.0f", $0)
                        }
                        SettingsDivider()
                        slider(NSLocalizedString("Grain", comment: ""), value: $theme.noiseOpacity, range: 0...0.3) {
                            String(format: "%.0f%%", $0 / 0.3 * 100)
                        }
                        SettingsDivider()
                        slider(NSLocalizedString("Color opacity", comment: ""), value: $theme.chromeOpacity, range: 0.3...1) {
                            String(format: "%.0f%%", $0 * 100)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            Divider()

            // Footer
            HStack(spacing: 10) {
                Button(NSLocalizedString("Export…", comment: "")) {
                    OvraFileManager.exportThemes([draft])
                }
                .buttonStyle(SettingsPillButtonStyle())
                Spacer()
                Button(NSLocalizedString("Cancel", comment: ""), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(SettingsPillButtonStyle())
                Button(isNew ? NSLocalizedString("Create Theme", comment: "") : NSLocalizedString("Save", comment: "")) {
                    onSave(draft.sanitized())
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(SettingsPillButtonStyle(prominent: true))
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 560, height: 680)
        .background(Color.settingsPage)
    }

    private func isAngle(_ angle: Double) -> Bool {
        let a = (theme.angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return abs(a - angle) < 0.5
    }

    private func shuffle() {
        let palette = ThemePalettes.random(count: colors.count)
        withAnimation(.easeInOut(duration: 0.25)) {
            colors = palette.map { Color(hex: $0) }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                        format: @escaping (Double) -> String) -> some View {
        SettingsItem(title: title) {
            HStack(spacing: 10) {
                Slider(value: value, in: range)
                    .controlSize(.small)
                    .frame(width: 200)
                    .accessibilityLabel(title)
                Text(format(value.wrappedValue))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(Color("UIText").opacity(0.6))
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

/// Pleasant random gradients for "New Theme" and "Shuffle".
enum ThemePalettes {
    static func random(count: Int = 3) -> [String] {
        let hue = Double.random(in: 0..<1)
        let spread = Double.random(in: 0.06...0.2) * (Bool.random() ? 1 : -1)
        let saturation = Double.random(in: 0.45...0.75)
        let brightness = Double.random(in: 0.45...0.8)
        return (0..<max(2, min(count, 4))).map { index in
            let h = (hue + spread * Double(index)).truncatingRemainder(dividingBy: 1)
            let color = NSColor(hue: h < 0 ? h + 1 : h, saturation: saturation,
                                brightness: max(0.2, brightness - 0.12 * Double(index)), alpha: 1)
            return Color(nsColor: color).toHex()
        }
    }
}
