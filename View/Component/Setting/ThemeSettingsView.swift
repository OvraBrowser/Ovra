import SwiftUI

struct ThemesSettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme: String = Theme.bluePurple.rawValue
    @AppStorage("customThemes") private var customThemesData: Data = Data()
    @ObservedObject var browser: Browser

    /// The theme open in the editor sheet, and whether it's a new one.
    @State private var editing: CustomTheme?
    @State private var editingIsNew = false
    @State private var pendingDelete: CustomTheme?
    @State private var importMessage: String?

    private var customThemes: [CustomTheme] { ThemeLibrary.decode(customThemesData) }

    private var currentEffects: ThemeEffects {
        ThemeEffects.resolve(selectedTheme: selectedTheme, customThemesData: customThemesData)
    }

    private var currentName: String {
        if let theme = Theme(rawValue: selectedTheme) { return theme.rawValue }
        return customThemes.first { $0.id.uuidString == selectedTheme }?.name ?? Theme.bluePurple.rawValue
    }

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsPageHeader(
                title: NSLocalizedString("Themes", comment: ""),
                subtitle: NSLocalizedString("The colors behind your sidebar, toolbar and start page.", comment: "")
            )

            // ── Live preview ──
            VStack(alignment: .leading, spacing: 10) {
                ThemePreview(effects: currentEffects)
                    .frame(height: 190)
                HStack {
                    Text(currentName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color("UIText"))
                    Spacer()
                    if let custom = customThemes.first(where: { $0.id.uuidString == selectedTheme }) {
                        Button(NSLocalizedString("Edit…", comment: "")) { beginEditing(custom) }
                            .buttonStyle(SettingsPillButtonStyle())
                    } else if let builtIn = Theme(rawValue: selectedTheme) {
                        Button(NSLocalizedString("Customize…", comment: "")) { beginCustomizing(builtIn) }
                            .buttonStyle(SettingsPillButtonStyle())
                    }
                }
            }

            // ── Built-in ──
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(NSLocalizedString("Built-in", comment: ""))
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Theme.allCases) { theme in
                        ThemeCard(
                            effects: ThemeEffects(theme),
                            name: theme.rawValue,
                            isSelected: selectedTheme == theme.rawValue
                        ) {
                            select(theme.rawValue)
                        }
                        .contextMenu {
                            Button(NSLocalizedString("Use Theme", comment: "")) { select(theme.rawValue) }
                            Button(NSLocalizedString("Customize…", comment: "")) { beginCustomizing(theme) }
                            Button(NSLocalizedString("Export…", comment: "")) {
                                OvraFileManager.exportThemes([CustomTheme(copying: theme)])
                            }
                        }
                    }
                }
            }

            // ── Custom ──
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionTitle(NSLocalizedString("Your Themes", comment: ""))
                    Spacer()
                    Button {
                        importThemes()
                    } label: {
                        Label(NSLocalizedString("Import…", comment: ""), systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(SettingsPillButtonStyle())
                    if !customThemes.isEmpty {
                        Button {
                            OvraFileManager.exportThemes(customThemes)
                        } label: {
                            Label(NSLocalizedString("Export All…", comment: ""), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(SettingsPillButtonStyle())
                    }
                    Button {
                        beginCreating()
                    } label: {
                        Label(NSLocalizedString("New Theme", comment: ""), systemImage: "plus")
                    }
                    .buttonStyle(SettingsPillButtonStyle(prominent: true))
                }

                if let importMessage {
                    Text(importMessage)
                        .font(.system(size: 12))
                        .foregroundColor(Color("UIText").opacity(0.7))
                        .transition(.opacity)
                }

                if customThemes.isEmpty {
                    emptyCustomState
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(customThemes) { theme in
                            ThemeCard(
                                effects: ThemeEffects(theme),
                                name: theme.name,
                                isSelected: selectedTheme == theme.id.uuidString,
                                hasEffects: theme.hasEffects
                            ) {
                                select(theme.id.uuidString)
                            }
                            .overlay(alignment: .topTrailing) {
                                Menu {
                                    customThemeMenu(theme)
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(.black.opacity(0.28)))
                                }
                                .menuStyle(.borderlessButton)
                                .menuIndicator(.hidden)
                                .fixedSize()
                                .padding(6)
                                .accessibilityLabel(String(format: NSLocalizedString("Options for %@", comment: ""), theme.name))
                            }
                            .contextMenu { customThemeMenu(theme) }
                        }
                    }
                }

                Text(NSLocalizedString("Themes are saved as .ovratheme files when you export them. Send one to a friend — they can double-click it to add it to Ovra.", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(Color("UIText").opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(item: $editing) { theme in
            ThemeEditorView(theme: theme, isNew: editingIsNew) { saved in
                ThemeLibrary.save(saved)
                select(saved.id.uuidString)
                editing = nil
            } onCancel: {
                editing = nil
            }
        }
        .alert(
            NSLocalizedString("Delete this theme?", comment: ""),
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { theme in
            Button(NSLocalizedString("Delete", comment: ""), role: .destructive) {
                withAnimation { ThemeLibrary.delete(theme) }
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: { theme in
            Text(String(format: NSLocalizedString("“%@” will be removed. Export it first if you want to keep a copy.", comment: ""), theme.name))
        }
    }

    // MARK: - Pieces

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color("UIText"))
    }

    @ViewBuilder
    private func customThemeMenu(_ theme: CustomTheme) -> some View {
        Button(NSLocalizedString("Use Theme", comment: "")) { select(theme.id.uuidString) }
        Button(NSLocalizedString("Edit…", comment: "")) { beginEditing(theme) }
        Button(NSLocalizedString("Duplicate", comment: "")) {
            withAnimation { _ = ThemeLibrary.duplicate(theme) }
        }
        Button(NSLocalizedString("Export…", comment: "")) { OvraFileManager.exportThemes([theme]) }
        Divider()
        Button(NSLocalizedString("Delete…", comment: ""), role: .destructive) { pendingDelete = theme }
    }

    private var emptyCustomState: some View {
        VStack(spacing: 10) {
            Image(systemName: "paintpalette")
                .font(.system(size: 22))
                .foregroundColor(Color("UIText").opacity(0.35))
            Text(NSLocalizedString("Make a theme with your own colors, direction and glass effects — or import one someone shared with you.", comment: ""))
                .font(.system(size: 12))
                .foregroundColor(Color("UIText").opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            HStack(spacing: 8) {
                Button(NSLocalizedString("Create Theme", comment: "")) { beginCreating() }
                    .buttonStyle(SettingsPillButtonStyle(prominent: true))
                Button(NSLocalizedString("Import Theme…", comment: "")) { importThemes() }
                    .buttonStyle(SettingsPillButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color("UIText").opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }

    // MARK: - Actions

    private func select(_ id: String) {
        withAnimation(.easeInOut(duration: 0.25)) { selectedTheme = id }
    }

    private func beginCreating() {
        let palette = ThemePalettes.random()
        editingIsNew = true
        editing = CustomTheme(name: ThemeLibrary.uniqueName(NSLocalizedString("My Theme", comment: "")), colorHexes: palette)
    }

    private func beginCustomizing(_ theme: Theme) {
        var copy = CustomTheme(copying: theme)
        copy.name = ThemeLibrary.uniqueName(String(format: NSLocalizedString("%@ Custom", comment: ""), theme.rawValue))
        editingIsNew = true
        editing = copy
    }

    private func beginEditing(_ theme: CustomTheme) {
        editingIsNew = false
        editing = theme
    }

    private func importThemes() {
        let added = OvraFileManager.importThemesWithPanel()
        guard let first = added.first else { return }
        select(first.id.uuidString)
        withAnimation {
            importMessage = added.count == 1
                ? String(format: NSLocalizedString("Imported “%@”.", comment: ""), first.name)
                : String(format: NSLocalizedString("Imported %d themes.", comment: ""), added.count)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { importMessage = nil }
        }
    }
}

// MARK: - Preview of the browser window on a theme

struct ThemePreview: View {
    let effects: ThemeEffects
    var compact = false

    var body: some View {
        let radius: CGFloat = compact ? 9 : 14
        let fg = effects.foreground
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(effects.gradient)
                .opacity(effects.chromeOpacity)
            if effects.blurRadius > 0 {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(min(effects.blurRadius / 30.0, 0.6))
            }
            if effects.noiseOpacity > 0.001 {
                NoiseTexture(opacity: effects.noiseOpacity)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }

            GeometryReader { geo in
                let pad: CGFloat = compact ? 5 : 8
                let sidebarWidth = geo.size.width * 0.24
                HStack(spacing: pad) {
                    // Sidebar
                    VStack(alignment: .leading, spacing: compact ? 3 : 5) {
                        HStack(spacing: compact ? 2 : 3) {
                            ForEach(["#FF5F57", "#FEBC2E", "#28C840"], id: \.self) { hex in
                                Circle().fill(Color(hex: hex)).frame(width: compact ? 3.5 : 6, height: compact ? 3.5 : 6)
                            }
                        }
                        .padding(.bottom, compact ? 2 : 4)
                        RoundedRectangle(cornerRadius: 3).fill(Color.white).frame(height: compact ? 6 : 12)
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2).fill(Color.black.opacity(0.1)).frame(height: compact ? 4 : 7)
                                .padding(.trailing, compact ? 6 : 14)
                        }
                        Spacer()
                    }
                    .padding(compact ? 4 : 7)
                    .frame(width: sidebarWidth)
                    .background(RoundedRectangle(cornerRadius: compact ? 5 : 9, style: .continuous).fill(Color.glassPanel))

                    // Toolbar + page
                    VStack(spacing: pad) {
                        HStack(spacing: compact ? 3 : 6) {
                            Capsule().fill(fg.opacity(0.22)).frame(width: geo.size.width * 0.1)
                            Capsule().fill(Color.white.opacity(0.95))
                            Capsule().fill(fg.opacity(0.22)).frame(width: geo.size.width * 0.12)
                        }
                        .frame(height: compact ? 7 : 14)

                        VStack(spacing: compact ? 3 : 6) {
                            Circle().fill(fg.opacity(0.9)).frame(width: compact ? 8 : 16, height: compact ? 8 : 16)
                            if !compact {
                                Text(NSLocalizedString("Good morning", comment: ""))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(fg)
                            }
                            HStack(spacing: compact ? 3 : 6) {
                                ForEach(0..<4, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: compact ? 2 : 4, style: .continuous)
                                        .fill(Color.white.opacity(0.9))
                                        .frame(width: compact ? 9 : 18, height: compact ? 9 : 18)
                                }
                            }
                            HStack(spacing: compact ? 3 : 6) {
                                RoundedRectangle(cornerRadius: compact ? 3 : 6).fill(fg.opacity(0.14))
                                RoundedRectangle(cornerRadius: compact ? 3 : 6).fill(fg.opacity(0.14))
                            }
                            .frame(height: compact ? 10 : 26)
                            .padding(.horizontal, compact ? 6 : 16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(pad)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let effects: ThemeEffects
    let name: String
    let isSelected: Bool
    var hasEffects: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                ThemePreview(effects: effects, compact: true)
                    .frame(height: 84)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(isSelected ? Color.settingsAccent : .clear, lineWidth: 2.5)
                            .padding(-3.5)
                    )
                    .shadow(color: .black.opacity(isHovered ? 0.16 : 0.07), radius: isHovered ? 6 : 2, y: 2)
                    .padding(.top, 3.5)
                    .padding(.horizontal, 3.5)

                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.settingsAccent)
                    }
                    Text(name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(Color("UIText"))
                        .lineLimit(1)
                    if hasEffects {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundColor(Color("UIText").opacity(0.5))
                            .help(NSLocalizedString("Uses glass or grain effects", comment: ""))
                    }
                }
                .padding(.horizontal, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
