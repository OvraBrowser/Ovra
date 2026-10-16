//
//  OnboardingView.swift
//  Ovra
//
//  Created by Ovra on 3/7/26.
//

import SwiftUI
import SwiftData

// MARK: - Steps

private enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case name
    case theme
    case searchEngine
    case look
    case done
}

// MARK: - Main View

struct OnboardingView: View {
    var onFinish: () -> Void
    /// Shared with the intro stage so its glow follows the chosen theme.
    @Binding var chosenTheme: Theme

    @AppStorage("selectedTheme") private var selectedTheme: String = Theme.bluePurple.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @Query var generalSettings: [GeneralSetting]

    @State private var step: OnboardingStep = .welcome
    @State private var goingForward = true
    @FocusState private var nameFocused: Bool

    // Local selections (committed on finish)
    @State private var name: String = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
    @State private var chosenEngine: String = "Google"
    @State private var chosenMode: String = "System"
    @State private var chosenLanguage: String = "English"

    private var effects: ThemeEffects { ThemeEffects(chosenTheme) }
    private var fg: Color { effects.foreground }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canContinue: Bool {
        step != .name || !trimmedName.isEmpty
    }

    var body: some View {
        ZStack {
            chosenTheme.gradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.45), value: chosenTheme)

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 22)

                Spacer(minLength: 16)

                Group {
                    switch step {
                    case .welcome: welcomeStep
                    case .name: nameStep
                    case .theme: themeStep
                    case .searchEngine: searchEngineStep
                    case .look: lookStep
                    case .done: doneStep
                    }
                }
                .frame(maxWidth: 620)
                .transition(.asymmetric(
                    insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
                ))
                .id(step)

                Spacer(minLength: 16)

                navigation
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, 40)
        }
        .foregroundColor(fg)
        .onAppear {
            let system = Locale.preferredLanguages.first ?? "en"
            if let match = languageOptions.first(where: { system.hasPrefix($0.code) }) {
                chosenLanguage = match.name
            }
        }
    }

    // MARK: - Chrome

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(fg.opacity(s.rawValue <= step.rawValue ? 0.9 : 0.25))
                    .frame(width: s == step ? 28 : 8, height: 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
        .accessibilityElement()
        .accessibilityLabel(String(format: NSLocalizedString("Step %d of %d", comment: ""), step.rawValue + 1, OnboardingStep.allCases.count))
    }

    private var navigation: some View {
        HStack(spacing: 12) {
            if step != .welcome && step != .done {
                Button(action: goBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                        Text(NSLocalizedString("Back", comment: "")).font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Capsule().fill(fg.opacity(0.16)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            Spacer()

            Button(action: step == .done ? finish : goNext) {
                HStack(spacing: 6) {
                    Text(primaryTitle).font(.system(size: 14, weight: .semibold))
                    if step != .done {
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                    }
                }
                .foregroundColor(effects.usesDarkText ? .white : Color(red: 0.11, green: 0.11, blue: 0.12))
                .padding(.horizontal, 22)
                .frame(height: 40)
                .background(Capsule().fill(effects.usesDarkText ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.5)
        }
        .frame(maxWidth: 620)
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: return NSLocalizedString("Get Started", comment: "")
        case .done: return NSLocalizedString("Start Browsing", comment: "")
        default: return NSLocalizedString("Continue", comment: "")
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            Image("MainLogo")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
                .accessibilityHidden(true)
            Text(NSLocalizedString("Welcome to Ovra", comment: ""))
                .font(.system(size: 38, weight: .bold))
                .tracking(-0.6)
            Text(NSLocalizedString("A fast browser that blocks trackers and looks the way you want. Let's set it up — it takes a minute.", comment: ""))
                .font(.system(size: 15))
                .opacity(0.85)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            HStack(spacing: 12) {
                featurePill("shield.lefthalf.filled", NSLocalizedString("Tracker blocking", comment: ""))
                featurePill("sidebar.left", NSLocalizedString("Tab sidebar", comment: ""))
                featurePill("paintpalette", NSLocalizedString("Your own themes", comment: ""))
            }
            .padding(.top, 10)
        }
    }

    private var nameStep: some View {
        VStack(spacing: 18) {
            stepHeader(NSLocalizedString("What should we call you?", comment: ""),
                       NSLocalizedString("Ovra greets you by name on the start page.", comment: ""))

            TextField(NSLocalizedString("Your name", comment: ""), text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                .padding(.horizontal, 20)
                .frame(width: 380, height: 56)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.94)))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .focused($nameFocused)
                .onSubmit { if canContinue { goNext() } }
                .accessibilityLabel(NSLocalizedString("Your name", comment: ""))
                .onAppear { nameFocused = true }

            glassCard {
                HStack(spacing: 12) {
                    Image(systemName: "lock.laptopcomputer")
                        .font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Your profile stays on this Mac", comment: ""))
                            .font(.system(size: 13, weight: .semibold))
                        Text(NSLocalizedString("Ovra accounts that sync your tabs, bookmarks and settings across devices are coming later.", comment: ""))
                            .font(.system(size: 12))
                            .opacity(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(width: 420)
        }
    }

    private var themeStep: some View {
        VStack(spacing: 20) {
            stepHeader(NSLocalizedString("Pick your colors", comment: ""),
                       NSLocalizedString("You can make your own themes later in Settings.", comment: ""))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(Theme.allCases) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { chosenTheme = theme }
                    } label: {
                        VStack(spacing: 6) {
                            ThemePreview(effects: ThemeEffects(theme), compact: true)
                                .frame(height: 62)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .strokeBorder(chosenTheme == theme ? fg : .clear, lineWidth: 2.5)
                                        .padding(-3.5)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                            Text(theme.rawValue)
                                .font(.system(size: 11, weight: chosenTheme == theme ? .semibold : .regular))
                                .lineLimit(1)
                        }
                        .padding(3.5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(theme.rawValue)
                    .accessibilityAddTraits(chosenTheme == theme ? .isSelected : [])
                }
            }
        }
    }

    private var searchEngineStep: some View {
        VStack(spacing: 20) {
            stepHeader(NSLocalizedString("Search with", comment: ""),
                       NSLocalizedString("Used when you type in the address bar. Change it any time.", comment: ""))

            glassCard(padding: 6) {
                VStack(spacing: 2) {
                    ForEach(SEARCH_ENGINE_LIST, id: \.name) { engine in
                        engineRow(engine)
                    }
                }
            }
            .frame(width: 420)
        }
    }

    private var lookStep: some View {
        VStack(spacing: 20) {
            stepHeader(NSLocalizedString("Look & language", comment: ""),
                       NSLocalizedString("Ovra follows your Mac by default.", comment: ""))

            HStack(spacing: 14) {
                appearanceCard(mode: "System", icon: "circle.lefthalf.filled", label: NSLocalizedString("Automatic", comment: ""))
                appearanceCard(mode: "Light", icon: "sun.max.fill", label: NSLocalizedString("Light", comment: ""))
                appearanceCard(mode: "Dark", icon: "moon.fill", label: NSLocalizedString("Dark", comment: ""))
            }
            .frame(width: 460)

            glassCard {
                HStack {
                    Image(systemName: "globe")
                    Text(NSLocalizedString("Language", comment: ""))
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker(NSLocalizedString("Language", comment: ""), selection: $chosenLanguage) {
                        ForEach(languageOptions, id: \.name) { option in
                            Text(option.name).tag(option.name)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .frame(width: 460)
        }
    }

    private var doneStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .frame(width: 72, height: 72)
                .background(Circle().fill(fg.opacity(0.18)))
                .accessibilityHidden(true)
            Text(String(format: NSLocalizedString("You're all set, %@", comment: ""), trimmedName))
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.5)
                .multilineTextAlignment(.center)

            glassCard {
                VStack(spacing: 10) {
                    summaryRow("paintpalette", NSLocalizedString("Theme", comment: ""), chosenTheme.rawValue)
                    summaryRow("magnifyingglass", NSLocalizedString("Search", comment: ""), chosenEngine)
                    summaryRow("circle.lefthalf.filled", NSLocalizedString("Appearance", comment: ""), modeLabel(chosenMode))
                    summaryRow("globe", NSLocalizedString("Language", comment: ""), chosenLanguage)
                }
            }
            .frame(width: 380)

            Text(NSLocalizedString("Tip: back up or move Ovra any time in Settings › Backup & Import.", comment: ""))
                .font(.system(size: 12))
                .opacity(0.75)
        }
    }

    // MARK: - Pieces

    private func stepHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.4)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 14))
                .opacity(0.8)
                .multilineTextAlignment(.center)
        }
    }

    private func glassCard<Content: View>(padding: CGFloat = 16, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fg.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(fg.opacity(0.2), lineWidth: 0.5)
                    )
            )
    }

    private func featurePill(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(title).font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Capsule().fill(fg.opacity(0.16)))
    }

    private func engineRow(_ engine: SearchEngine) -> some View {
        let isChosen = chosenEngine == engine.name
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { chosenEngine = engine.name }
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let img = decodeBase64(engine.favicon) {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).padding(4)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                    }
                }
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white))

                Text(engine.name)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .opacity(isChosen ? 1 : 0.45)
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fg.opacity(isChosen ? 0.16 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func appearanceCard(mode: String, icon: String, label: String) -> some View {
        let isChosen = chosenMode == mode
        let isDark = mode == "Dark" || (mode == "System" && colorScheme == .dark)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { chosenMode = mode }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isDark ? Color(white: 0.14) : Color.white)
                    if mode == "System" {
                        HStack(spacing: 0) {
                            Color.white
                            Color(white: 0.14)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(mode == "System" ? .gray : (isDark ? .white : Color(white: 0.15)))
                }
                .frame(height: 84)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isChosen ? fg : .clear, lineWidth: 2.5)
                        .padding(-3.5)
                )
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                Text(label)
                    .font(.system(size: 12, weight: isChosen ? .semibold : .regular))
            }
            .padding(3.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func summaryRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).frame(width: 18).opacity(0.75)
            Text(label).font(.system(size: 13)).opacity(0.8)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold))
        }
    }

    private func modeLabel(_ mode: String) -> String {
        switch mode {
        case "Light": return NSLocalizedString("Light", comment: "")
        case "Dark": return NSLocalizedString("Dark", comment: "")
        default: return NSLocalizedString("Automatic", comment: "")
        }
    }

    // MARK: - Navigation

    private func goNext() {
        guard canContinue, let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        goingForward = true
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    private func goBack() {
        guard let prev = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        goingForward = false
        withAnimation(.easeInOut(duration: 0.3)) { step = prev }
    }

    private func finish() {
        LocalProfile.name = trimmedName
        selectedTheme = chosenTheme.rawValue
        SettingsManager.setSearchEngine(chosenEngine)
        SettingsManager.setScreenMode(chosenMode)

        // Only pin a language when it differs from the Mac's own.
        let code = languageCodeForName(chosenLanguage)
        let system = Locale.preferredLanguages.first ?? "en"
        if !system.hasPrefix(code) {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }

        // A brand-new user doesn't need "What's New" for the version they installed.
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            UserDefaults.standard.set(version, forKey: "lastWhatsNewVersion")
        }
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onFinish()
    }

    // MARK: - Helpers

    private func decodeBase64(_ base64: String) -> NSImage? {
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return nil }
        return NSImage(data: data)
    }

    private struct LanguageOption {
        let code: String
        let name: String
    }

    private let languageOptions: [LanguageOption] = [
        .init(code: "en", name: "English"),
        .init(code: "de", name: "Deutsch"),
        .init(code: "es", name: "Español"),
        .init(code: "fr", name: "Français"),
        .init(code: "hi", name: "हिन्दी"),
        .init(code: "ja", name: "日本語"),
        .init(code: "ko", name: "한국어"),
        .init(code: "nb", name: "Norsk"),
        .init(code: "zh-Hans", name: "中文"),
    ]

    private func languageCodeForName(_ name: String) -> String {
        languageOptions.first(where: { $0.name == name })?.code ?? "en"
    }
}
