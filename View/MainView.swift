import SwiftUI

struct MainView: View {
    @ObservedObject var service: Service
    @ObservedObject var browser: Browser
    @EnvironmentObject var windowDelegate: OvraWindowDelegate

    @AppStorage("selectedTheme") private var selectedTheme: String = Theme.bluePurple.rawValue
    @AppStorage("customThemes") private var customThemesData: Data = Data()

    private var effects: ThemeEffects {
        ThemeEffects.resolve(selectedTheme: selectedTheme, customThemesData: customThemesData)
    }

    /// Height of the toolbar row; matches the unified titlebar so the
    /// traffic lights sit centred in it.
    static let toolbarHeight: CGFloat = 52

    var body: some View {
        ZStack {
            // Layer 1: Vibrancy / frosted glass (shows desktop when chromeOpacity < 1)
            if effects.blurRadius > 0 {
                VisualEffectNSView()
                    .edgesIgnoringSafeArea(.all)
            }

            // Layer 2: Gradient with adjustable opacity
            effects.gradient
                .opacity(effects.chromeOpacity)
                .edgesIgnoringSafeArea(.all)

            // Layer 3: Frosted blur on top of gradient
            if effects.blurRadius > 0 {
                Color.white.opacity(0.001) // invisible layer to apply blur
                    .background(.ultraThinMaterial)
                    .opacity(min(effects.blurRadius / 30.0, 0.6))
                    .edgesIgnoringSafeArea(.all)
            }

            // Layer 4: Noise texture
            if effects.noiseOpacity > 0.001 {
                NoiseTexture(opacity: effects.noiseOpacity)
                    .edgesIgnoringSafeArea(.all)
            }

            // Layer 5: Browser content
            HStack(spacing: 10) {
                if browser.isTabSidebar {
                    OvraSidebar(service: service, browser: browser)
                        .padding(.top, 10)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        NavigationSearchView(
                            service: service,
                            browser: browser,
                            activeTabId: $browser.activeTabId,
                            isFullScreen: $windowDelegate.isFullScreen
                        )

                        if let activeId = browser.activeTabId,
                           let tab = browser.tabs.first(where: { $0.id == activeId }) {
                            TabContentView(
                                service: service,
                                browser: browser,
                                tab: tab,
                                isActive: true,
                                geometryHeight: max(geometry.size.height - MainView.toolbarHeight, 0)
                            )
                        }
                    }
                }

                if browser.isSideBar {
                    SideBarView(service: service, browser: browser)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.top, MainView.toolbarHeight)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding([.leading, .trailing, .bottom], 10)
            .edgesIgnoringSafeArea(.top)
        }
        .onAppear {
            GuidedTipController.shared.startTourIfNeeded()
        }
    }
}
