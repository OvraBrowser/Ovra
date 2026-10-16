//
//  SettingsView.swift
//  Ovra
//
//

import SwiftUI
import SwiftData

struct SettingsView: View {
  @Query var generalSettings: [GeneralSetting]
  @Binding var selectedCategory: SettingsCategory
  @ObservedObject var browser: Browser

  init(browser: Browser) {
    self.browser = browser
    self._selectedCategory = Binding(get: {
      browser.selectedSettingsCategory
    }, set: {
      browser.selectedSettingsCategory = $0
    })
  }

  var body: some View {
    HStack(spacing: 0) {
      SettingsSidebar(selectedCategory: $selectedCategory)
        .padding(8)

      SettingsContent(selectedCategory: selectedCategory, generalSettings: generalSettings, browser: browser)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.settingsPage)
  }
}

enum SettingsCategory: String, CaseIterable {
  case general = "General"
  case Theme = "Themes"
  case backup = "Backup & Import"
  case permissions = "Permissions"
  case searchHistory = "Search History"
  case visitHistory = "Visit History"
  case library = "Licenses"
  case About = "About"

  var localizedTitle: String {
    NSLocalizedString(self.rawValue, comment: "")
  }

  var icon: String {
    switch self {
    case .general: return "gearshape.fill"
    case .Theme: return "paintpalette.fill"
    case .backup: return "arrow.up.arrow.down"
    case .permissions: return "hand.raised.fill"
    case .searchHistory: return "magnifyingglass"
    case .visitHistory: return "clock.fill"
    case .library: return "doc.text.fill"
    case .About: return "info"
    }
  }

  var iconColors: [Color] {
    switch self {
    case .general: return [Color(hex: "#8E8E93"), Color(hex: "#6E6E73")]
    case .Theme: return [Color(hex: "#BF5AF2"), Color(hex: "#5E5CE6")]
    case .backup: return [Color(hex: "#30D158"), Color(hex: "#20A848")]
    case .permissions: return [Color(hex: "#0A84FF"), Color(hex: "#0060DF")]
    case .searchHistory: return [Color(hex: "#8E8E93"), Color(hex: "#636366")]
    case .visitHistory: return [Color(hex: "#FF9F0A"), Color(hex: "#F07800")]
    case .library: return [Color(hex: "#64D2FF"), Color(hex: "#30A8E0")]
    case .About: return [Color(hex: "#636366"), Color(hex: "#48484A")]
    }
  }

  /// Extra words the sidebar search matches.
  var keywords: [String] {
    switch self {
    case .general: return ["language", "search engine", "appearance", "dark", "light", "tracker", "privacy", "retention"]
    case .Theme: return ["color", "gradient", "appearance", "custom", "wallpaper"]
    case .backup: return ["export", "import", "restore", "file", "share", "ovrabackup", "ovratheme"]
    case .permissions: return ["location", "notifications", "camera", "site"]
    case .searchHistory: return ["clear", "search"]
    case .visitHistory: return ["history", "clear", "visited"]
    case .library: return ["license", "open source"]
    case .About: return ["version", "update", "contact"]
    }
  }
}
