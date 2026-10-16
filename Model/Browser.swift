//
//  Browser.swift
//  Ovra
//
//

import SwiftUI
import WebKit

enum SettingsSection {
    case General
    case About
}


final class Browser: ObservableObject, Identifiable {
  var id: UUID
  var windowNumber: Int
  @Published var tabs: [Tab] = []
  @Published var activeTabId: UUID?
  @Published var isSideBar: Bool = false
  /// Left glass sidebar with vertical tabs. Remembered across launches.
  @Published var isTabSidebar: Bool = UserDefaults.standard.object(forKey: "isTabSidebar") as? Bool ?? true {
    didSet { UserDefaults.standard.set(isTabSidebar, forKey: "isTabSidebar") }
  }
    @Published var settingsTab: SettingsSection = .General
    @Published var selectedSettingsCategory: SettingsCategory = .general

  @Published var searchBoxRect: CGRect?
  
  init(service: Service, windowNumber: Int, tabId: UUID? = nil) {
    self.id = UUID()
    self.windowNumber = windowNumber
    if let tabId = tabId {
      self.moveNewBrowserTab(service: service, tabId: tabId)
    } else {
      self.initTab()
    }
  }
  
  func initTab() {
    let newTab = Tab(url: EMPTY_URL)
    newTab.isInit = true
    newTab.isInitFocus = true
    DispatchQueue.main.async {
      self.tabs.append(newTab)
      self.activeTabId = newTab.id
    }
  }
  
  func moveNewBrowserTab(service: Service, tabId: UUID) {
    for (_, targetBrowser) in service.browsers {
      if let targetTabIndex = targetBrowser.tabs.firstIndex(where: { $0.id == tabId }) {
        let targetTab = targetBrowser.tabs[targetTabIndex]
        tabs.append(targetTab)
        activeTabId = targetTab.id
        
        targetBrowser.tabs.remove(at: targetTabIndex)
        if targetBrowser.tabs.count > 0 {
          let newTargetTabIndex = targetTabIndex == 0 ? 0 : targetTabIndex - 1
          targetBrowser.activeTabId = targetBrowser.tabs[newTargetTabIndex].id
        }
        break
      }
    }
  }
  
  func clearSearchEditMode() {
    for index in tabs.indices {
      tabs[index].isEditSearch = false
      tabs[index].autoCompleteList = []
      tabs[index].autoCompleteIndex = nil
      tabs[index].autoCompleteText = ""
    }
  }
  
  func updateActiveTab(tabId: UUID, webView: WKWebView) {
    DispatchQueue.main.async {
      self.clearSearchEditMode()
      self.activeTabId = tabId
    }
  }
  
  func newTab(_ url: URL = DEFAULT_URL) {
    let newTab = Tab(url: url)
    DispatchQueue.main.async {
      self.clearSearchEditMode()
      self.tabs.append(newTab)
      self.activeTabId = newTab.id
    }
  }
  
  func openSettings() {
    let newTab = Tab(url: EMPTY_URL, type: "Settings")
    newTab.isSetting = true
    DispatchQueue.main.async {
      self.clearSearchEditMode()
      self.tabs.append(newTab)
      self.activeTabId = newTab.id
    }
  }
  
  /// Opens Settings on the given section, reusing an open Settings tab.
  func showSettings(category: SettingsCategory) {
    selectedSettingsCategory = category
    if let settingsTab = tabs.first(where: { $0.isSetting }) {
      clearSearchEditMode()
      activeTabId = settingsTab.id
    } else {
      openSettings()
    }
  }

  func closeTab(_ tab: Tab) {
    guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
    let removeTabId = tab.id
    tab.closeTab {
      guard let removeIndex = self.tabs.firstIndex(where: { $0.id == removeTabId }) else { return }
      self.tabs.remove(at: removeIndex)
      if self.tabs.isEmpty {
        AppDelegate.shared.closeWindow()
      } else {
        if self.activeTabId == removeTabId {
          let targetIndex = self.tabs.count > index ? index : self.tabs.count - 1
          self.activeTabId = self.tabs[targetIndex].id
        }
        AppDelegate.shared.closeInspector(removeTabId)
      }
    }
  }

  func closeAllTab(completion: @escaping () -> Void) {
    let group = DispatchGroup()
    for tab in tabs {
      group.enter()
      tab.closeTab {
        group.leave()
      }
    }
    group.notify(queue: .main) {
      completion()
    }
  }
}
