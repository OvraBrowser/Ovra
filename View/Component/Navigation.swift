//
//  TitleView.swift
//  Ovra
//
//

import SwiftUI

struct Navigation: View {
    @ObservedObject var service: Service
    @ObservedObject var browser: Browser
    @ObservedObject var tab: Tab
    @EnvironmentObject var windowDelegate: OvraWindowDelegate

    @State private var isMoreMenuDialog = false
    @State private var isDownloadsPopover = false
    @State private var isFindDetailDialog = true
    @State private var isNotificationDetailDialog = true

    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var tipController = GuidedTipController.shared

    @AppStorage("selectedTheme") private var selectedTheme: String = Theme.bluePurple.rawValue
    // Observed so text colour updates when a custom theme is edited.
    @AppStorage("customThemes") private var customThemesData: Data = Data()
    @State private var isTabOverview = false

    private var tint: Color { ThemeForeground.color(for: selectedTheme) }

    private var shareURL: URL? {
        guard !tab.isInit, !tab.isSetting, let scheme = tab.originURL.scheme, scheme.hasPrefix("http") else { return nil }
        return tab.originURL
    }

    var body: some View {
        HStack(spacing: 10) {
            // Leave room for the traffic lights when the sidebar is hidden
            if !browser.isTabSidebar && !windowDelegate.isFullScreen {
                Spacer().frame(width: 70)
            }

            // ── Navigation controls ──
            GlassCapsule(tint: tint) {
                if !browser.isTabSidebar {
                    GlassToolbarButton(icon: "sidebar.left", label: NSLocalizedString("Show Sidebar", comment: ""), tint: tint) {
                        withAnimation(.easeInOut(duration: 0.2)) { browser.isTabSidebar = true }
                    }
                }
                HistoryBackBtn(browser: browser, tab: tab)
                    .guidedTip(.shortcuts, arrowEdge: .bottom)
                HistoryForwardBtn(browser: browser, tab: tab)
                if tab.pageProgress > 0 && tab.pageProgress < 1 {
                    GlassToolbarButton(icon: "xmark", label: NSLocalizedString("Stop", comment: ""), tint: tint) {
                        DispatchQueue.main.async { tab.stopProcess = true }
                    }
                } else {
                    GlassToolbarButton(icon: "arrow.clockwise", label: NSLocalizedString("Reload", comment: ""), tint: tint, isEnabled: !tab.isInit && !tab.isSetting) {
                        AppDelegate.shared.refreshTab()
                    }
                    .guidedTip(.newTab, arrowEdge: .bottom)
                }
            }

            // ── Address pill (drawn by SearchEditBox over this placeholder) ──
            HStack {
                Spacer(minLength: 0)
                SearchBoxArea(browser: browser)
                    .frame(maxWidth: 680)
                    .guidedTip(.addressBar, arrowEdge: .bottom)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            // ── Contextual icons (only when active) ──
            if tab.isZoomDialog || tab.isFindDialog || tab.isNotificationDialogIcon || tab.isLocationDialogIcon {
                GlassCapsule(tint: tint) {
                    if tab.isZoomDialog {
                        GlassToolbarButton(icon: "plus.magnifyingglass", label: NSLocalizedString("Zoom", comment: ""), tint: tint, isActive: true) {
                            tab.isZoomDialog.toggle()
                        }
                        .popover(isPresented: $tab.isZoomDialog, arrowEdge: .bottom) {
                            ZoomDialog(tab: tab)
                        }
                    }

                    if tab.isFindDialog {
                        GlassToolbarButton(icon: "doc.text.magnifyingglass", label: NSLocalizedString("Find", comment: ""), tint: tint, isActive: true) {}
                            .onAppear { isFindDetailDialog = true }
                            .onChange(of: isFindDetailDialog) { _, nV in
                                if !nV { tab.isFindDialog = false }
                            }
                            .popover(isPresented: $isFindDetailDialog, arrowEdge: .bottom) {
                                FindDialog(tab: tab)
                            }
                    }

                    if tab.isNotificationDialogIcon {
                        GlassToolbarButton(icon: "bell.slash", label: NSLocalizedString("Notifications", comment: ""), tint: tint) {
                            isNotificationDetailDialog.toggle()
                        }
                        .onAppear { isNotificationDetailDialog = true }
                        .popover(isPresented: $isNotificationDetailDialog, arrowEdge: .bottom) {
                            NotificationDialog(tab: tab)
                        }
                    }

                    if tab.isLocationDialogIcon {
                        GlassToolbarButton(icon: "location.slash", label: NSLocalizedString("Location", comment: ""), tint: tint) {
                            tab.isLocationDialog.toggle()
                        }
                        .popover(isPresented: $tab.isLocationDialog, arrowEdge: .bottom) {
                            GeoLocationDialog()
                        }
                    }
                }
            }

            // ── Persistent toolbar actions ──
            GlassCapsule(tint: tint) {
                GlassToolbarButton(icon: "arrow.down.circle", label: NSLocalizedString("Downloads", comment: ""), tint: tint, isActive: isDownloadsPopover, badge: downloadManager.hasActiveDownloads) {
                    isDownloadsPopover.toggle()
                }
                .popover(isPresented: $isDownloadsPopover, arrowEdge: .bottom) {
                    DownloadsPopover()
                }
                .guidedTip(.downloads, arrowEdge: .top)

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(tint)
                            .frame(width: 40, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("Share", comment: ""))
                }

                GlassToolbarButton(icon: "plus", label: NSLocalizedString("New Tab", comment: ""), tint: tint) {
                    browser.initTab()
                }

                GlassToolbarButton(icon: "square.grid.2x2", label: NSLocalizedString("Tab Overview", comment: ""), tint: tint, isActive: isTabOverview) {
                    isTabOverview.toggle()
                }
                .popover(isPresented: $isTabOverview, arrowEdge: .bottom) {
                    TabDialog(service: service, browser: browser, tabs: $browser.tabs, activeTabId: $browser.activeTabId)
                }
                .guidedTip(.sidebar, arrowEdge: .top)

                GlassToolbarButton(icon: "ellipsis", label: NSLocalizedString("More", comment: ""), tint: tint, isActive: isMoreMenuDialog) {
                    isMoreMenuDialog.toggle()
                }
                .popover(isPresented: $isMoreMenuDialog, arrowEdge: .bottom) {
                    MoreMenuDialog(browser: browser, tab: tab, isMoreMenuDialog: $isMoreMenuDialog)
                }
                .guidedTip(.moreMenu, arrowEdge: .top)
            }
        }
        .frame(height: MainView.toolbarHeight)
    }
}
