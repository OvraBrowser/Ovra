import SwiftUI

struct WhatsNewView: View {
    @ObservedObject var manager: WhatsNewManager
    var onClose: () -> Void

    @AppStorage("selectedTheme") private var selectedTheme: String = Theme.bluePurple.rawValue
    @AppStorage("customThemes") private var customThemesData: Data = Data()

    @State private var appeared = false

    private var effects: ThemeEffects {
        ThemeEffects.resolve(selectedTheme: selectedTheme, customThemesData: customThemesData)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let version = manager.latestVersion {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(Array(version.items.enumerated()), id: \.element.id) { index, item in
                            WhatsNewRow(item: item)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 10)
                                .animation(.easeOut(duration: 0.35).delay(0.05 * Double(index)), value: appeared)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.settingsAccent)
                    Text(NSLocalizedString("You're up to date", comment: ""))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color("UIText"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider().opacity(0.5)

            HStack {
                Button(NSLocalizedString("Release history", comment: "")) {
                    if let url = URL(string: "https://github.com/OvraBrowser/Ovra/releases") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(SettingsPillButtonStyle())
                Spacer()
                Button(NSLocalizedString("Continue", comment: "")) { onClose() }
                    .buttonStyle(SettingsPillButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 500, height: 640)
        .background(Color.settingsPage)
        .onAppear { appeared = true }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            effects.gradient
            if effects.noiseOpacity > 0.001 {
                NoiseTexture(opacity: effects.noiseOpacity)
            }
            VStack(alignment: .leading, spacing: 10) {
                Image("MainLogo")
                    .resizable()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("What's New", comment: ""))
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.4)
                if let version = manager.latestVersion {
                    Text(String(format: NSLocalizedString("%@ · Version %@", comment: ""), version.title, version.version))
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.85)
                }
            }
            .foregroundColor(effects.foreground)
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        .frame(height: 200)
        .clipped()
    }
}

private struct WhatsNewRow: View {
    let item: WhatsNewEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SettingsIconBadge(symbol: item.icon, colors: [Color(hex: item.colorHex), Color(hex: item.colorHex).opacity(0.8)], size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("UIText"))
                Text(item.description)
                    .font(.system(size: 12.5))
                    .foregroundColor(Color("UIText").opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.settingsCard)
                .shadow(color: .black.opacity(0.06), radius: 0.5)
        )
    }
}
