//
//  GeneralSettingsView.swift
//  Ovra
//
//


import SwiftUI
import SwiftData
import Sparkle

struct GeneralSettingsView: View {
  @Environment(\.modelContext) var modelContext
  @ObservedObject var browser: Browser
  let generalSettings: [GeneralSetting]
  
  init(browser: Browser, generalSettings: [GeneralSetting]) {
    self.browser = browser
    self.generalSettings = generalSettings
  }
  
  @State private var selectedLanguage: String = "English"
  @State private var selectedScreenMode: String = "System"
  @State private var selectedSearchEngine: String = "Google"
  @State private var selectedRetentionPeriod: String = "1 Week"
  @State private var isTrackerBlocking: Bool = true
  @AppStorage(LocalProfile.nameKey) private var profileName: String = ""
  @State private var nameDraft: String = ""
  @State private var isConfirmingReset = false
  @State private var autoCheckUpdates = true
  @State private var autoDownloadUpdates = false
  @State private var lastUpdateCheck: Date?

  private var updater: SPUUpdater? { AppDelegate.shared.updaterController?.updater }
  @State private var isResetting = false

  /// Ignore the onChange fired while the current values are loaded.
  @State private var isLoaded = false
  
  // 각 언어를 해당 언어로 표시
  private let languageOptions = [
    ("English", "English"),
    ("Norwegian", "Norsk"),
    ("Hindi", "हिन्दी"),
    ("Korean", "한국어"),
    ("Chinese", "中文"),
    ("German", "Deutsch"),
    ("Japanese", "日本語"),
    ("Spanish", "Español"),
    ("French", "Français")
  ]
  private let screenModes = ["System", "Light", "Dark"]
  private let searchEngines = ["Google", "Bing", "Yahoo", "DuckDuckGo"]
  private let retentionPeriods = ["1 Day", "1 Week", "1 Month", "Indefinite"]
  
  private var trackerBinding: Binding<Bool> {
    Binding(get: { isTrackerBlocking }, set: { isTrackerBlocking = $0 })
  }

  private var tabSidebarBinding: Binding<Bool> {
    Binding(
      get: { browser.isTabSidebar },
      set: { newValue in
        for other in AppDelegate.shared.service.browsers.values {
          withAnimation(.easeInOut(duration: 0.2)) { other.isTabSidebar = newValue }
        }
      }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      SettingsPageHeader(title: NSLocalizedString("General", comment: ""))

      SettingsGroup(
        title: NSLocalizedString("Profile", comment: ""),
        footer: NSLocalizedString("Your profile lives on this Mac. Ovra accounts that sync across your devices are coming later.", comment: "")
      ) {
        SettingsItem(title: NSLocalizedString("Name", comment: "")) {
          TextField(LocalProfile.displayName(""), text: $nameDraft)
            .textFieldStyle(.roundedBorder)
            .frame(width: 220)
            .onSubmit { LocalProfile.name = nameDraft }
            .onChange(of: nameDraft) { _, newValue in LocalProfile.name = newValue }
        }
      }

      SettingsGroup(title: NSLocalizedString("Appearance", comment: "")) {
        SettingsItem(title: NSLocalizedString("Screen Mode", comment: "")) {
          Picker(NSLocalizedString("Screen Mode", comment: ""), selection: $selectedScreenMode) {
            ForEach(screenModes, id: \.self) { mode in
              Text(NSLocalizedString(mode, comment: "")).tag(NSLocalizedString(mode, comment: ""))
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .frame(width: 220)
        }
        SettingsDivider()
        SettingsToggleItem(
          title: NSLocalizedString("Show tab sidebar", comment: ""),
          subtitle: NSLocalizedString("Tabs and your library on the left of every window.", comment: ""),
          isOn: tabSidebarBinding
        )
        SettingsDivider()
        SettingsButtonItem(
          title: NSLocalizedString("Themes", comment: ""),
          subtitle: NSLocalizedString("Colors and effects behind your tabs", comment: "")
        ) {
          browser.selectedSettingsCategory = .Theme
        }
      }

      SettingsGroup(title: NSLocalizedString("Search", comment: "")) {
        SettingsItem(title: NSLocalizedString("Search Engine", comment: "")) {
          Picker(NSLocalizedString("Search Engine", comment: ""), selection: $selectedSearchEngine) {
            ForEach(searchEngines, id: \.self) { Text($0).tag($0) }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .fixedSize()
        }
      }

      SettingsGroup(
        title: NSLocalizedString("Privacy", comment: ""),
        footer: NSLocalizedString("Blocks unnecessary ads and trackers using DuckDuckGo's tracking protection list along with additional rules.", comment: "")
      ) {
        SettingsToggleItem(title: NSLocalizedString("Block ads and trackers", comment: ""), isOn: trackerBinding)
        SettingsDivider()
        SettingsButtonItem(title: NSLocalizedString("Site permissions", comment: "")) {
          browser.selectedSettingsCategory = .permissions
        }
        SettingsDivider()
        SettingsButtonItem(title: NSLocalizedString("Learn more about blocking", comment: ""), icon: "arrow.up.right") {
          browser.newTab(URL(string: "https://github.com/OvraBrowser/Ovra/tree/main/Packages/ContentBlockRuleList")!)
        }
      }

      SettingsGroup(title: NSLocalizedString("History", comment: "")) {
        SettingsItem(
          title: NSLocalizedString("Remove history items", comment: ""),
          subtitle: NSLocalizedString("Older pages and searches are deleted automatically.", comment: "")
        ) {
          Picker(NSLocalizedString("Retention Period", comment: ""), selection: $selectedRetentionPeriod) {
            ForEach(retentionPeriods, id: \.self) { period in
              Text(NSLocalizedString(period, comment: "")).tag(NSLocalizedString(period, comment: ""))
            }
          }
          .labelsHidden()
          .fixedSize()
        }
        SettingsDivider()
        SettingsButtonItem(title: NSLocalizedString("Visit history", comment: "")) {
          browser.selectedSettingsCategory = .visitHistory
        }
        SettingsDivider()
        SettingsButtonItem(title: NSLocalizedString("Search history", comment: "")) {
          browser.selectedSettingsCategory = .searchHistory
        }
      }

      SettingsGroup(
        title: NSLocalizedString("Language", comment: ""),
        footer: NSLocalizedString("Ovra uses the new language the next time it opens.", comment: "")
      ) {
        SettingsItem(title: NSLocalizedString("Language", comment: "")) {
          Picker(NSLocalizedString("Language", comment: ""), selection: $selectedLanguage) {
            ForEach(languageOptions.map { $0.1 }, id: \.self) { Text($0).tag($0) }
          }
          .labelsHidden()
          .fixedSize()
        }
      }

      SettingsGroup(
        title: NSLocalizedString("Updates", comment: ""),
        footer: lastUpdateCheck.map {
          String(format: NSLocalizedString("Last checked %@.", comment: ""), $0.formatted(.relative(presentation: .named)))
        }
      ) {
        SettingsItem(
          title: String(format: NSLocalizedString("Ovra %@", comment: ""), Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""),
          subtitle: String(format: NSLocalizedString("Build %@", comment: ""), Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")
        ) {
          Button(NSLocalizedString("Check Now", comment: "")) {
            AppDelegate.shared.updaterController?.checkForUpdates(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { lastUpdateCheck = updater?.lastUpdateCheckDate }
          }
          .buttonStyle(SettingsPillButtonStyle())
        }
        SettingsDivider()
        SettingsToggleItem(
          title: NSLocalizedString("Check for updates automatically", comment: ""),
          subtitle: NSLocalizedString("Once a day.", comment: ""),
          isOn: Binding(get: { autoCheckUpdates }, set: { newValue in
            autoCheckUpdates = newValue
            updater?.automaticallyChecksForUpdates = newValue
            if !newValue {
              autoDownloadUpdates = false
              updater?.automaticallyDownloadsUpdates = false
            }
          })
        )
        SettingsDivider()
        SettingsToggleItem(
          title: NSLocalizedString("Download and install automatically", comment: ""),
          subtitle: NSLocalizedString("Updates install the next time you quit Ovra.", comment: ""),
          isOn: Binding(get: { autoDownloadUpdates }, set: { newValue in
            autoDownloadUpdates = newValue
            updater?.automaticallyDownloadsUpdates = newValue
          })
        )
        .disabled(!autoCheckUpdates)
        .opacity(autoCheckUpdates ? 1 : 0.5)
      }

      SettingsGroup(title: NSLocalizedString("Backup", comment: "")) {
        SettingsButtonItem(
          title: NSLocalizedString("Back up or move Ovra", comment: ""),
          subtitle: NSLocalizedString("Export settings, themes, favorites and bookmarks to a file", comment: "")
        ) {
          browser.selectedSettingsCategory = .backup
        }
      }

      SettingsGroup(
        title: NSLocalizedString("Reset", comment: ""),
        footer: NSLocalizedString("Erases your profile, settings, themes, favorites, bookmarks, history, site permissions, cookies and website data, then restarts Ovra like a fresh install. Files in your Downloads folder are kept.", comment: "")
      ) {
        SettingsItem(title: NSLocalizedString("Reset Ovra", comment: "")) {
          Button(isResetting ? NSLocalizedString("Resetting…", comment: "") : NSLocalizedString("Reset Ovra…", comment: "")) {
            isConfirmingReset = true
          }
          .buttonStyle(SettingsPillButtonStyle(destructive: true))
          .disabled(isResetting)
        }
      }
    }
    .alert(NSLocalizedString("Reset Ovra to a fresh install?", comment: ""), isPresented: $isConfirmingReset) {
      Button(NSLocalizedString("Export Backup First…", comment: "")) {
        OvraFileManager.exportBackup(BackupContents())
      }
      Button(NSLocalizedString("Reset Everything", comment: ""), role: .destructive) {
        isResetting = true
        Task { await ResetManager.resetEverything() }
      }
      Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
    } message: {
      Text(NSLocalizedString("Everything Ovra stores on this Mac will be erased and Ovra will restart. This can't be undone — export a backup first if you might want it back.", comment: ""))
    }
    .onAppear {
      loadCurrentSettings()
    }
    .onChange(of: selectedLanguage) { _, newValue in
      updateLanguage(newValue)
    }
    .onChange(of: selectedScreenMode) { _, newValue in
      updateScreenMode(newValue)
    }
    .onChange(of: selectedSearchEngine) { _, newValue in
      updateSearchEngine(newValue)
    }
    .onChange(of: selectedRetentionPeriod) { _, newValue in
      updateRetentionPeriod(newValue)
    }
    .onChange(of: isTrackerBlocking) { _, newValue in
      updateTrackerBlocking(newValue)
    }
    .onChange(of: AppDelegate.shared.service.isTrackerBlocking) { _, newValue in
      if isTrackerBlocking != newValue { isTrackerBlocking = newValue }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }
  
  private func loadCurrentSettings() {
    guard let settings = generalSettings.first else { return }
    
    selectedScreenMode = mapScreenMode(settings.screenMode)
    selectedSearchEngine = settings.searchEngine
    selectedRetentionPeriod = mapRetentionPeriod(settings.retentionPeriod)
    isTrackerBlocking = settings.isTrackerBlocking
    
    // 현재 언어 가져오기
    let currentLanguage = (UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? Locale.current.language.languageCode?.identifier ?? "en").components(separatedBy: "-").first ?? "en"
    selectedLanguage = mapLanguageCode(currentLanguage)
    nameDraft = profileName
    if let updater {
      autoCheckUpdates = updater.automaticallyChecksForUpdates
      autoDownloadUpdates = updater.automaticallyDownloadsUpdates
      lastUpdateCheck = updater.lastUpdateCheckDate
    }
    DispatchQueue.main.async { isLoaded = true }
  }
  
  private func mapScreenMode(_ mode: String) -> String {
    switch mode {
    case "Light": return NSLocalizedString("Light", comment: "")
    case "Dark": return NSLocalizedString("Dark", comment: "")
    case "System": return NSLocalizedString("System", comment: "")
    default: return NSLocalizedString("System", comment: "")
    }
  }
  
  private func mapRetentionPeriod(_ period: String) -> String {
    switch period {
    case "1 Day": return NSLocalizedString("1 Day", comment: "")
    case "1 Week": return NSLocalizedString("1 Week", comment: "")
    case "1 Month": return NSLocalizedString("1 Month", comment: "")
    case "Indefinite": return NSLocalizedString("Indefinite", comment: "")
    default: return NSLocalizedString("1 Week", comment: "")
    }
  }
  
  private func mapLanguageCode(_ code: String) -> String {
    switch code {
    case "ko": return "한국어"
    case "en": return "English"
    case "de": return "Deutsch"
    case "es": return "Español"
    case "ja": return "日本語"
    case "zh": return "中文"
    case "fr": return "Français"
    case "hi": return "हिन्दी"
    case "no", "nb": return "Norsk"
    default: return "English"
    }
  }
  
  private func updateLanguage(_ language: String) {
    let languageCode: String
    switch language {
    case "한국어": languageCode = "ko"
    case "English": languageCode = "en"
    case "Deutsch": languageCode = "de"
    case "Español": languageCode = "es"
    case "日本語": languageCode = "ja"
    case "中文": languageCode = "zh-Hans"
    case "Français": languageCode = "fr"
    case "हिन्दी": languageCode = "hi"
    case "Norsk": languageCode = "nb"
    default: languageCode = "en"
    }
    
    // Only write when the user picks a language, so opening Settings doesn't pin one.
    guard isLoaded else { return }
    let current = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first
    guard current != languageCode else { return }
    UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
    UserDefaults.standard.synchronize()
  }
  
  private func updateScreenMode(_ mode: String) {
    let modeValue: String
    switch mode {
    case NSLocalizedString("Light", comment: ""): modeValue = "Light"
    case NSLocalizedString("Dark", comment: ""): modeValue = "Dark"
    case NSLocalizedString("System", comment: ""): modeValue = "System"
    default: modeValue = "System"
    }
    
    SettingsManager.setScreenMode(modeValue)
  }
  
  private func updateSearchEngine(_ engine: String) {
    SettingsManager.setSearchEngine(engine)
  }
  
  private func updateRetentionPeriod(_ period: String) {
    let periodValue: String
    switch period {
    case NSLocalizedString("1 Day", comment: ""): periodValue = "1 Day"
    case NSLocalizedString("1 Week", comment: ""): periodValue = "1 Week"
    case NSLocalizedString("1 Month", comment: ""): periodValue = "1 Month"
    case NSLocalizedString("Indefinite", comment: ""): periodValue = "Indefinite"
    default: periodValue = "1 Week"
    }
    
    SettingsManager.setRetentionPeriod(periodValue)
  }
  
  private func updateTrackerBlocking(_ isEnabled: Bool) {
    SettingsManager.setIsTrackerBlocking(isEnabled)
    AppDelegate.shared.service.isTrackerBlocking = isEnabled
  }
}
