//
//  AppDelegate.swift
//  Ovra
//
//

import SwiftUI
import SwiftData
import Sparkle
import AppKit



class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, ObservableObject {
  static var shared: AppDelegate!
    var updaterController: SPUStandardUpdaterController!
  
  weak var prevWindow: NSWindow?
  var windowMap: [UUID:NSWindow] = [:]
  private let whatsNewShownKey = "lastWhatsNewVersion"
  private var whatsNewWindow: NSWindow?
  private var onboardingWindow: NSWindow?

  var service: Service = Service()
  let windowDelegate = OvraWindowDelegate()
  
  var sidebarToggleMenuItem: NSMenuItem!
  var reloadMenuItem: NSMenuItem!
  
  @Published var isFullScreenMode: Bool = false
  @Published var isOpenSidebar: Bool = false
  
  
  override init() {
    super.init()
    NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey(notification:)), name: NSWindow.didResignKeyNotification, object: nil)
  }
  
  @objc func windowDidResignKey(notification: Notification) {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNo = keyWindow.windowNumber
      if let pWindow = self.prevWindow {
        if pWindow.windowNumber != windowNo {
          if pWindow.title == "" && keyWindow.title != "" {
            if !windowMap.values.contains(pWindow) {
              if let activeBrowser = service.browsers[pWindow.windowNumber], let tabId = activeBrowser.activeTabId {
                windowMap[tabId] = keyWindow
              }
            }
          }
        }
      }
      self.prevWindow = keyWindow
    }
  }

  @MainActor
  let modelContainer: ModelContainer = {
    let schema = Schema([GeneralSetting.self, DomainPermission.self, BookmarkGroup.self,  SearchHistoryGroup.self, VisitHistoryGroup.self, Favorite.self])
    // Debug builds only: `-OvraDemoProfile` starts with an empty in-memory
    // database plus sample favorites, for clean screenshots that never show
    // real history or bookmarks.
    #if DEBUG
    let isDemoProfile = ProcessInfo.processInfo.arguments.contains("-OvraDemoProfile")
    #else
    let isDemoProfile = false
    #endif
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isDemoProfile)
    do {
      let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
      
      let generalSettingDescriptor = FetchDescriptor<GeneralSetting>()
      if try container.mainContext.fetch(generalSettingDescriptor).count == 0 {
        container.mainContext.insert(GeneralSetting())
      }
      
      let baseBookmarkGroupDescriptor = FetchDescriptor<BookmarkGroup>(
        predicate: #Predicate { $0.isBase == true }
      )
      if try container.mainContext.fetch(baseBookmarkGroupDescriptor).count == 0 {
        let baseBookmarkGroup = BookmarkGroup(index: 0, depth: 0, name: "----", isBase: true)
        container.mainContext.insert(baseBookmarkGroup)
        if let baseGroup = try container.mainContext.fetch(baseBookmarkGroupDescriptor).first {
          baseGroup.bookmarkGroups.append(BookmarkGroup(index: 0, depth: 1))
        }
      }
      
      if isDemoProfile {
        for (title, address) in [("GitHub", "github.com"), ("Apple", "apple.com"), ("Wikipedia", "wikipedia.org"), ("YouTube", "youtube.com"), ("Figma", "figma.com")] {
          container.mainContext.insert(Favorite(title: title, address: address))
        }
      }

      return container
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()
  
  func createWindow(tabId: UUID? = nil, frame: NSRect? = nil) {
    var windowRect = NSRect(x: 0, y: 0, width: 1400, height: 800)
    var isWindowCenter = true
    
    if let frameString = UserDefaults.standard.string(forKey: "lastWindowFrame") {
      isWindowCenter = false
      windowRect = NSRectFromString(frameString)
    }
    
    if let paramFrame = frame {
      isWindowCenter = false
      windowRect = paramFrame
    }
    
    let newWindow = NSWindow(contentRect: windowRect,
                             styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
    newWindow.backgroundColor = NSColor(named: "WindowTitleBG")
    let newWindowNo = newWindow.windowNumber
    let newBrowser = Browser(service: service, windowNumber: newWindowNo, tabId: tabId)
    newBrowser.windowNumber = newWindowNo
    self.service.browsers[newWindowNo] = newBrowser
    
    let contentView = ContentView(tabId: tabId, width: windowRect.size.width)
      .environmentObject(self.windowDelegate)
      .environmentObject(self.service)
      .environmentObject(self.service.browsers[newWindowNo]!)
      .background(VisualEffectNSView())
      .frame(minWidth: 500, maxWidth: .infinity, minHeight: 350, maxHeight: .infinity)
      .modelContainer(modelContainer)
      
    
    let hostingController = NSHostingController(rootView: contentView)
    // Don't let SwiftUI push size constraints onto the window: the toolbar
    // overlay is positioned from measured frames and would keep re-triggering
    // window constraint passes.
    hostingController.sizingOptions = []
    newWindow.contentView = hostingController.view
    newWindow.contentMinSize = NSSize(width: 500, height: 350)
    
    if isWindowCenter {
      newWindow.center()
    }
    
    newWindow.titlebarAppearsTransparent = true
    newWindow.titleVisibility = .hidden
    newWindow.styleMask.insert(.fullSizeContentView)

    newWindow.makeKeyAndOrderFront(nil)
    newWindow.delegate = windowDelegate
    
    let windowController = NSWindowController(window: newWindow)
    windowController.showWindow(self)
     
    // No NSToolbar: it swallows clicks in the top strip where Ovra's own
    // toolbar lives. Instead the traffic lights are moved down by hand so
    // they line up with the sidebar header.
    OvraWindowDelegate.layoutTrafficLights(newWindow)
    
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding()
        } else {
            createWindow()
            showWhatsNewIfNeeded()
        }
    }

    func showOnboarding() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let cardSize = CGSize(width: min(820, screenFrame.width - 80), height: min(600, screenFrame.height - 120))

        // Full-screen, borderless and transparent: the intro dims the desktop,
        // then the orb grows into the onboarding window in the middle.
        let window = OnboardingStageWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered, defer: false
        )
        window.title = NSLocalizedString("Welcome to Ovra", comment: "")
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView:
            OnboardingStageView(screenSize: screenFrame.size, cardSize: cardSize, onComplete: { [weak self] in
                self?.onboardingWindow?.orderOut(nil)
                self?.onboardingWindow = nil
                self?.createWindow()
            })
            .modelContainer(modelContainer)
        )
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.setFrame(screenFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.onboardingWindow = window
    }

    func showWhatsNewIfNeeded() {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        let lastVersion = UserDefaults.standard.string(forKey: whatsNewShownKey)

        if lastVersion != currentVersion {
            UserDefaults.standard.set(currentVersion, forKey: whatsNewShownKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showWhatsNew()
            }
        }
    }

    /// Opens the What's New window (also from the Ovra menu and About).
    @objc func showWhatsNew() {
        if let existing = whatsNewWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 640),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = NSLocalizedString("What's New", comment: "")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        let hostingView = NSHostingController(rootView: WhatsNewView(manager: WhatsNewManager(), onClose: { [weak self] in
            self?.whatsNewWindow?.close()
            self?.whatsNewWindow = nil
        }).ignoresSafeArea())
        window.contentView = hostingView.view
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.whatsNewWindow = window
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.whatsNewWindow = nil
        }
    }

  
  func createNewWindow(tabId: UUID, frame: NSRect? = nil) {
    createWindow(tabId: tabId, frame: frame)
  }
  
  func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let dockMenu = NSMenu()
    dockMenu.addItem(NSMenuItem(title: NSLocalizedString("New Window", comment: ""), action: #selector(self.newWindow), keyEquivalent: ""))
    return dockMenu
  }
  
  @objc func refreshTab() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let target = self.service.browsers[windowNumber], let tab = target.tabs.first(where: { $0.id == target.activeTabId }), let webview = tab.webview {
        webview.reload()
        tab.clearPermission()
      }
    }
  }
  
  @objc func refreshTabAfterClearingCache() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let target = self.service.browsers[windowNumber], let tab = target.tabs.first(where: { $0.id == target.activeTabId }), let webview = tab.webview {
        clearCache {
          print("clearing cache")
          webview.reload()
          tab.clearPermission()
        }
      }
    }
  }
  
  func clearCache(completion: @escaping () -> Void) {
      URLCache.shared.removeAllCachedResponses()
      completion()
  }
  
  @objc func zoomIn() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let target = self.service.browsers[windowNumber], let activeId = target.activeTabId {
        if let targetTab = target.tabs.first(where: { $0.id == activeId }) {
          DispatchQueue.main.async {
            targetTab.isZoomDialog = true
            targetTab.zoomLevel = ((targetTab.zoomLevel * 10) + 1) / 10
          }
        }
      }
    }
  }
  
  @objc func zoomOut() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let target = self.service.browsers[windowNumber], let activeId = target.activeTabId {
        if let targetTab = target.tabs.first(where: { $0.id == activeId }) {
          DispatchQueue.main.async {
            targetTab.isZoomDialog = true
            targetTab.zoomLevel = ((targetTab.zoomLevel * 10) - 1) / 10
          }
        }
      }
    }
  }
  
  @objc func findKeywordPrev() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let target = self.service.browsers[windowNumber], let activeId = target.activeTabId {
        if let targetTab = target.tabs.first(where: { $0.id == activeId }), targetTab.isFindDialog {
          DispatchQueue.main.async {
            targetTab.isFindPrev = true
            targetTab.isFindAction = true
          }
        }
      }
    }
  }
  
  @objc func findKeywordNext() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let target = self.service.browsers[windowNumber], let activeId = target.activeTabId {
        if let targetTab = target.tabs.first(where: { $0.id == activeId }), targetTab.isFindDialog {
          DispatchQueue.main.async {
            targetTab.isFindPrev = false
            targetTab.isFindAction = true
          }
        }
      }
    }
  }
  
  @objc func findKeyword() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let target = self.service.browsers[windowNumber], let activeId = target.activeTabId {
        if let targetTab = target.tabs.first(where: { $0.id == activeId }) {
          DispatchQueue.main.async {
            targetTab.isFindDialog.toggle()
          }
        }
      }
    }
  }
  
  @objc func toggleFullScreen() {
    if let keyWindow = NSApplication.shared.keyWindow {
      keyWindow.toggleFullScreen(nil)
    }
  }
  
  @objc func exitApplication() {
    NSApplication.shared.terminate(self)
  }
  
  @objc func newWindow() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowFrame = keyWindow.frame
      let newWindowFrame = NSRect(x: windowFrame.origin.x + 30, y: windowFrame.origin.y - 20, width: windowFrame.width, height: windowFrame.height)
      createWindow(frame: newWindowFrame)
    } else {
      createWindow()
    }
  }
  
  @objc func newTab() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let target = self.service.browsers[windowNumber] {
        target.initTab()
      }
    } else{
      createWindow()
    }
  }
  
  @objc func closeWindow() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let browser = self.service.browsers[windowNumber] {
        let tabs = browser.tabs
        for tab in tabs {
          self.closeInspector(tab.id)
        }
        browser.closeAllTab {
          browser.tabs = []
          self.service.browsers[windowNumber] = nil
          keyWindow.close()
        }
      }
    }
  }
  
  func closeInspector(_ tabId: UUID) {
    if windowMap.keys.contains(tabId) {
      windowMap[tabId]!.close()
      windowMap.removeValue(forKey: tabId)
    }
  }
  
  @objc func closeTab() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let browser = self.service.browsers[windowNumber], let activeId = browser.activeTabId {
        if let targetRemoveIndex = browser.tabs.firstIndex(where: { $0.id == activeId }) {
          print("close tab clean up webview shortkey")
          let targetTab = browser.tabs[targetRemoveIndex]
          targetTab.closeTab {
            browser.tabs.remove(at: targetRemoveIndex)
            if browser.tabs.count == 0 {
              keyWindow.close()
            } else {
              let targetIndex = browser.tabs.count > targetRemoveIndex ? targetRemoveIndex : browser.tabs.count - 1
              browser.activeTabId = browser.tabs[targetIndex].id
            }
          }
        }
        self.closeInspector(activeId)
      } else {
        for (key, value) in windowMap {
          if value == keyWindow {
            windowMap.removeValue(forKey: key)
          }
        }
        keyWindow.close()
      }
    }
  }
  
  @objc func isSidebar() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let target = self.service.browsers[windowNumber] {
        target.isSideBar = !target.isSideBar
        isOpenSidebar = !isOpenSidebar
      }
    }
  }
  
    @objc func openAboutWindow() {
        if let keyWindow = NSApplication.shared.keyWindow {
            let windowNumber = keyWindow.windowNumber
            if let target = self.service.browsers[windowNumber] {
                target.selectedSettingsCategory = .About
                target.openSettings()
            }
        }
    }
  
  @objc func openSettings() {
    if let keyWindow = NSApplication.shared.keyWindow {
      let windowNumber = keyWindow.windowNumber
      if let target = self.service.browsers[windowNumber] {
        target.openSettings()
      }
    }
  }
  
  /// Double-clicked .ovratheme / .ovrabackup files.
  func application(_ application: NSApplication, open urls: [URL]) {
    let ovraFiles = urls.filter { ["ovratheme", "ovrabackup"].contains($0.pathExtension.lowercased()) }
    guard !ovraFiles.isEmpty else { return }
    // Give a freshly launched app a moment to open its first window.
    DispatchQueue.main.asyncAfter(deadline: .now() + (service.browsers.isEmpty ? 0.6 : 0)) {
      if self.service.browsers.isEmpty && UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        self.createWindow()
      }
      for url in ovraFiles {
        OvraFileManager.open(url)
      }
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      createWindow()
    }
    return false
  }
  
  @MainActor func deleteExpiredData() {
    do {
      let generalSettingDescriptor = FetchDescriptor<GeneralSetting>()
      if let generalSetting = try AppDelegate.shared.modelContainer.mainContext.fetch(generalSettingDescriptor).first {
        if generalSetting.retentionPeriod != DataRententionPeriodList.indefinite.rawValue {
          let calendar = Calendar.current
          let today = Date()
          
          let searchHistory = FetchDescriptor<SearchHistory>()
          let searchHistories = try AppDelegate.shared.modelContainer.mainContext.fetch(searchHistory)
                    
          for searchData in searchHistories {
            let components = calendar.dateComponents([.day], from: searchData.createDate, to: today)
            if let days = components.day {
              if (generalSetting.retentionPeriod == DataRententionPeriodList.oneDay.rawValue && days >= 1)
                  || (generalSetting.retentionPeriod == DataRententionPeriodList.oneWeek.rawValue && days >= 7)
                  || (generalSetting.retentionPeriod == DataRententionPeriodList.oneMonth.rawValue && days >= 30) {
                AppDelegate.shared.modelContainer.mainContext.delete(searchData)
              }
            }
          }
          
          let searchHistoryGroupDescriptor = FetchDescriptor<SearchHistoryGroup>()
          let searchHistoryGroups = try AppDelegate.shared.modelContainer.mainContext.fetch(searchHistoryGroupDescriptor)
          
          for group in searchHistoryGroups {
            if group.searchHistories.isEmpty {
              AppDelegate.shared.modelContainer.mainContext.delete(group)
            }
          }

          let visitHistory = FetchDescriptor<VisitHistory>()
          let visitHIstories = try AppDelegate.shared.modelContainer.mainContext.fetch(visitHistory)
          
          for visitData in visitHIstories {
            let components = calendar.dateComponents([.day], from: visitData.createDate, to: today)
            if let days = components.day {
              if (generalSetting.retentionPeriod == DataRententionPeriodList.oneDay.rawValue && days >= 1)
                  || (generalSetting.retentionPeriod == DataRententionPeriodList.oneWeek.rawValue && days >= 7)
                  || (generalSetting.retentionPeriod == DataRententionPeriodList.oneMonth.rawValue && days >= 30) {
                AppDelegate.shared.modelContainer.mainContext.delete(visitData)
              }
            }
          }
          
          let visitHistoryGroupDescriptor = FetchDescriptor<VisitHistoryGroup>()
          let visitHistoryGroups = try AppDelegate.shared.modelContainer.mainContext.fetch(visitHistoryGroupDescriptor)
          
          for group in visitHistoryGroups {
            if group.visitHistories.isEmpty {
              AppDelegate.shared.modelContainer.mainContext.delete(group)
            }
          }
          
          try AppDelegate.shared.modelContainer.mainContext.save()
        }
      }
    } catch {
      fatalError("Could not deleteExpiredData ModelContainer: \(error)")
    }
  }
}
