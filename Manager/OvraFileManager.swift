//
//  OvraFileManager.swift
//  Ovra
//
//  Ovra's own file types:
//  • .ovratheme  — one or more custom themes, to share or keep.
//  • .ovrabackup — settings, themes, favorites and bookmarks, to back up or
//                  move to another Mac.
//  Both are plain JSON with a `format` + `version` header.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType {
  static let ovraTheme = UTType(exportedAs: "com.ovra.browser.theme", conformingTo: .json)
  static let ovraBackup = UTType(exportedAs: "com.ovra.browser.backup", conformingTo: .json)
}

// MARK: - File formats

struct OvraThemeFile: Codable {
  static let formatID = "com.ovra.theme"
  var format = OvraThemeFile.formatID
  var version = 1
  var exportedAt = Date()
  var themes: [CustomTheme]
}

struct OvraBackup: Codable {
  static let formatID = "com.ovra.backup"
  var format = OvraBackup.formatID
  var version = 1
  var createdAt = Date()
  var appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  var deviceName: String = Host.current().localizedName ?? ""

  var settings: Settings?
  var appearance: Appearance?
  var favorites: [FavoriteEntry]?
  var bookmarks: BookmarkFolder?

  struct Settings: Codable {
    var searchEngine: String
    var screenMode: String
    var retentionPeriod: String
    var isTrackerBlocking: Bool
    var profileName: String?
  }

  struct Appearance: Codable {
    var selectedTheme: String
    var customThemes: [CustomTheme]
    var showsTabSidebar: Bool?
  }

  struct FavoriteEntry: Codable {
    var title: String
    var address: String
  }

  struct BookmarkEntry: Codable {
    var title: String
    var url: String
  }

  struct BookmarkFolder: Codable {
    var name: String
    var bookmarks: [BookmarkEntry]
    var folders: [BookmarkFolder]

    var bookmarkCount: Int {
      bookmarks.count + folders.reduce(0) { $0 + $1.bookmarkCount }
    }
  }

  /// Short, human summary of what's inside ("12 bookmarks · 3 themes …").
  var summary: [String] {
    var parts: [String] = []
    if settings != nil { parts.append(NSLocalizedString("Settings", comment: "")) }
    if let appearance {
      let count = appearance.customThemes.count
      parts.append(count == 1
                   ? NSLocalizedString("Theme + 1 custom theme", comment: "")
                   : String(format: NSLocalizedString("Theme + %d custom themes", comment: ""), count))
    }
    if let favorites { parts.append(String(format: NSLocalizedString("%d favorites", comment: ""), favorites.count)) }
    if let bookmarks { parts.append(String(format: NSLocalizedString("%d bookmarks", comment: ""), bookmarks.bookmarkCount)) }
    return parts
  }
}

/// What to put in (or take out of) a backup.
struct BackupContents: Equatable {
  var settings = true
  var appearance = true
  var favorites = true
  var bookmarks = true

  var isEmpty: Bool { !settings && !appearance && !favorites && !bookmarks }

  init(settings: Bool = true, appearance: Bool = true, favorites: Bool = true, bookmarks: Bool = true) {
    self.settings = settings
    self.appearance = appearance
    self.favorites = favorites
    self.bookmarks = bookmarks
  }

  init(available backup: OvraBackup) {
    settings = backup.settings != nil
    appearance = backup.appearance != nil
    favorites = backup.favorites != nil
    bookmarks = backup.bookmarks != nil
  }
}

struct RestoreResult {
  var settingsRestored = false
  var themesAdded = 0
  var favoritesAdded = 0
  var bookmarksAdded = 0
  var skippedDuplicates = 0

  var message: String {
    var lines: [String] = []
    if settingsRestored { lines.append(NSLocalizedString("Settings restored", comment: "")) }
    if themesAdded > 0 { lines.append(String(format: NSLocalizedString("%d themes added", comment: ""), themesAdded)) }
    if favoritesAdded > 0 { lines.append(String(format: NSLocalizedString("%d favorites added", comment: ""), favoritesAdded)) }
    if bookmarksAdded > 0 { lines.append(String(format: NSLocalizedString("%d bookmarks added", comment: ""), bookmarksAdded)) }
    if skippedDuplicates > 0 { lines.append(String(format: NSLocalizedString("%d already existed and were skipped", comment: ""), skippedDuplicates)) }
    return lines.isEmpty ? NSLocalizedString("Nothing new to restore.", comment: "") : lines.joined(separator: "\n")
  }
}

enum OvraFileError: LocalizedError {
  case tooLarge, unreadable, wrongFormat, newerVersion

  var errorDescription: String? {
    switch self {
    case .tooLarge: return NSLocalizedString("This file is too large to be an Ovra file.", comment: "")
    case .unreadable: return NSLocalizedString("This file couldn't be read. It may be damaged.", comment: "")
    case .wrongFormat: return NSLocalizedString("This isn't an Ovra theme or backup file.", comment: "")
    case .newerVersion: return NSLocalizedString("This file was made by a newer version of Ovra. Update Ovra to open it.", comment: "")
    }
  }
}

// MARK: - Reading & writing

@MainActor
enum OvraFileManager {
  private static let maxFileSize = 20 * 1024 * 1024

  private static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  private static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  private static func readData(_ url: URL) throws -> Data {
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    guard size <= maxFileSize else { throw OvraFileError.tooLarge }
    guard let data = try? Data(contentsOf: url) else { throw OvraFileError.unreadable }
    return data
  }

  // MARK: Themes

  static func themeFileData(_ themes: [CustomTheme]) throws -> Data {
    try encoder.encode(OvraThemeFile(themes: themes.map { $0.sanitized() }))
  }

  static func readThemes(from url: URL) throws -> [CustomTheme] {
    let data = try readData(url)
    if let file = try? decoder.decode(OvraThemeFile.self, from: data), file.format == OvraThemeFile.formatID {
      guard file.version <= 1 else { throw OvraFileError.newerVersion }
      return file.themes.map { $0.sanitized() }
    }
    // A single bare theme is accepted too.
    if let theme = try? decoder.decode(CustomTheme.self, from: data), !theme.colorHexes.isEmpty {
      return [theme.sanitized()]
    }
    throw OvraFileError.wrongFormat
  }

  // MARK: Backup

  static func makeBackup(_ contents: BackupContents) -> OvraBackup {
    var backup = OvraBackup()
    let context = AppDelegate.shared.modelContainer.mainContext

    if contents.settings, let s = SettingsManager.getGeneralSettings() {
      backup.settings = .init(searchEngine: s.searchEngine, screenMode: s.screenMode,
                              retentionPeriod: s.retentionPeriod, isTrackerBlocking: s.isTrackerBlocking,
                              profileName: LocalProfile.name.isEmpty ? nil : LocalProfile.name)
    }
    if contents.appearance {
      backup.appearance = .init(selectedTheme: ThemeLibrary.selectedThemeID,
                                customThemes: ThemeLibrary.customThemes,
                                showsTabSidebar: UserDefaults.standard.object(forKey: "isTabSidebar") as? Bool)
    }
    if contents.favorites {
      let favorites = (try? context.fetch(FetchDescriptor<Favorite>(sortBy: [SortDescriptor(\.createDate)]))) ?? []
      backup.favorites = favorites.map { .init(title: $0.title, address: $0.address) }
    }
    if contents.bookmarks, let base = BookmarkManager.getBaseBookmarkGroup() {
      backup.bookmarks = folder(from: base)
    }
    return backup
  }

  private static func folder(from group: BookmarkGroup) -> OvraBackup.BookmarkFolder {
    .init(
      name: group.name,
      bookmarks: group.bookmarks.sorted { $0.index < $1.index }.map { .init(title: $0.title, url: $0.url) },
      folders: group.bookmarkGroups.sorted { $0.index < $1.index }.map { folder(from: $0) }
    )
  }

  static func backupData(_ backup: OvraBackup) throws -> Data {
    try encoder.encode(backup)
  }

  static func readBackup(from url: URL) throws -> OvraBackup {
    let data = try readData(url)
    guard let backup = try? decoder.decode(OvraBackup.self, from: data) else {
      throw OvraFileError.wrongFormat
    }
    guard backup.format == OvraBackup.formatID else { throw OvraFileError.wrongFormat }
    guard backup.version <= 1 else { throw OvraFileError.newerVersion }
    return backup
  }

  /// Restores the chosen parts. Settings and the selected theme are replaced;
  /// themes, favorites and bookmarks are merged (duplicates are skipped).
  @discardableResult
  static func restore(_ backup: OvraBackup, parts: BackupContents) -> RestoreResult {
    var result = RestoreResult()
    let context = AppDelegate.shared.modelContainer.mainContext

    if parts.settings, let s = backup.settings {
      SettingsManager.setSearchEngine(s.searchEngine)
      SettingsManager.setScreenMode(s.screenMode)
      SettingsManager.setRetentionPeriod(s.retentionPeriod)
      SettingsManager.setIsTrackerBlocking(s.isTrackerBlocking)
      AppDelegate.shared.service.isTrackerBlocking = s.isTrackerBlocking
      if let name = s.profileName, !name.isEmpty { LocalProfile.name = name }
      result.settingsRestored = true
    }

    if parts.appearance, let appearance = backup.appearance {
      var themes = ThemeLibrary.customThemes
      for theme in appearance.customThemes.map({ $0.sanitized() }) {
        if let index = themes.firstIndex(where: { $0.id == theme.id }) {
          if themes[index] != theme { themes[index] = theme }
          else { result.skippedDuplicates += 1 }
        } else {
          themes.append(theme)
          result.themesAdded += 1
        }
      }
      ThemeLibrary.customThemes = themes
      let selected = appearance.selectedTheme
      if Theme(rawValue: selected) != nil || themes.contains(where: { $0.id.uuidString == selected }) {
        ThemeLibrary.selectedThemeID = selected
      }
      if let sidebar = appearance.showsTabSidebar {
        for browser in AppDelegate.shared.service.browsers.values { browser.isTabSidebar = sidebar }
        UserDefaults.standard.set(sidebar, forKey: "isTabSidebar")
      }
    }

    if parts.favorites, let favorites = backup.favorites {
      let existing = Set(((try? context.fetch(FetchDescriptor<Favorite>())) ?? []).map { normalized($0.address) })
      for entry in favorites {
        guard !entry.address.isEmpty else { continue }
        if existing.contains(normalized(entry.address)) {
          result.skippedDuplicates += 1
          continue
        }
        if FavoriteManager.addFavorite(Favorite(title: entry.title, address: entry.address)) {
          result.favoritesAdded += 1
        }
      }
    }

    if parts.bookmarks, let root = backup.bookmarks, let base = BookmarkManager.getBaseBookmarkGroup() {
      var existingURLs = Set(((try? context.fetch(FetchDescriptor<Bookmark>())) ?? []).map(\.url))
      merge(folder: root, into: base, existingURLs: &existingURLs, result: &result)
    }

    try? context.save()
    return result
  }

  private static func merge(folder: OvraBackup.BookmarkFolder, into group: BookmarkGroup,
                            existingURLs: inout Set<String>, result: inout RestoreResult) {
    for entry in folder.bookmarks {
      guard !entry.url.isEmpty else { continue }
      // Bookmark URLs are unique in the database.
      if existingURLs.contains(entry.url) {
        result.skippedDuplicates += 1
        continue
      }
      BookmarkManager.addBookmark(bookmarkGroup: group, title: entry.title, url: entry.url)
      existingURLs.insert(entry.url)
      result.bookmarksAdded += 1
    }
    for child in folder.folders {
      let target: BookmarkGroup
      if let match = group.bookmarkGroups.first(where: { $0.name == child.name }) {
        target = match
      } else {
        let newGroup = BookmarkGroup(index: group.bookmarkGroups.count, depth: group.depth + 1, name: child.name)
        group.bookmarkGroups.append(newGroup)
        target = newGroup
      }
      merge(folder: child, into: target, existingURLs: &existingURLs, result: &result)
    }
  }

  private static func normalized(_ address: String) -> String {
    var value = address.lowercased()
    for prefix in ["https://", "http://", "www."] where value.hasPrefix(prefix) {
      value.removeFirst(prefix.count)
    }
    while value.hasSuffix("/") { value.removeLast() }
    return value
  }

  // MARK: - Panels

  static func exportThemes(_ themes: [CustomTheme]) {
    guard !themes.isEmpty else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.ovraTheme]
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = themes.count == 1 ? themes[0].name : NSLocalizedString("Ovra Themes", comment: "")
    panel.message = NSLocalizedString("Share this file with anyone who uses Ovra. Double-click it to add the theme.", comment: "")
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try themeFileData(themes).write(to: url, options: .atomic)
    } catch {
      showError(error)
    }
  }

  /// Lets the user pick `.ovratheme` files and adds them. Returns what was added.
  static func importThemesWithPanel() -> [CustomTheme] {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.ovraTheme, .json]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.message = NSLocalizedString("Choose one or more .ovratheme files", comment: "")
    guard panel.runModal() == .OK else { return [] }
    var added: [CustomTheme] = []
    for url in panel.urls {
      do {
        added += ThemeLibrary.add(imported: try readThemes(from: url))
      } catch {
        showError(error, file: url)
      }
    }
    return added
  }

  static func exportBackup(_ contents: BackupContents) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.ovraBackup]
    panel.canCreateDirectories = true
    let date = Date().formatted(.iso8601.year().month().day())
    panel.nameFieldStringValue = "Ovra Backup \(date)"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try backupData(makeBackup(contents)).write(to: url, options: .atomic)
      NSWorkspace.shared.activateFileViewerSelecting([url])
    } catch {
      showError(error)
    }
  }

  static func pickBackup() -> OvraBackup? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.ovraBackup, .json]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.message = NSLocalizedString("Choose an .ovrabackup file", comment: "")
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    do {
      return try readBackup(from: url)
    } catch {
      showError(error, file: url)
      return nil
    }
  }

  // MARK: - Opening files from Finder

  /// Handles a double-clicked `.ovratheme` / `.ovrabackup` file.
  static func open(_ url: URL) {
    switch url.pathExtension.lowercased() {
    case "ovratheme":
      do {
        let added = ThemeLibrary.add(imported: try readThemes(from: url))
        guard let first = added.first else { return }
        ThemeLibrary.selectedThemeID = first.id.uuidString
        showThemesSettings()
        let alert = NSAlert()
        alert.messageText = added.count == 1
          ? String(format: NSLocalizedString("“%@” was added to your themes", comment: ""), first.name)
          : String(format: NSLocalizedString("%d themes were added", comment: ""), added.count)
        alert.informativeText = NSLocalizedString("It's now your active theme. You can change it any time in Settings › Themes.", comment: "")
        alert.runModal()
      } catch {
        showError(error, file: url)
      }

    case "ovrabackup":
      do {
        let backup = try readBackup(from: url)
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Restore this Ovra backup?", comment: "")
        let created = backup.createdAt.formatted(date: .abbreviated, time: .shortened)
        alert.informativeText = String(
          format: NSLocalizedString("Made on %@ (%@).\n\nContains: %@.\n\nSettings and theme will be replaced. Favorites, bookmarks and custom themes are added to what you have.", comment: ""),
          created, backup.deviceName, backup.summary.joined(separator: ", ")
        )
        alert.addButton(withTitle: NSLocalizedString("Restore", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let result = restore(backup, parts: BackupContents(available: backup))
        let done = NSAlert()
        done.messageText = NSLocalizedString("Backup restored", comment: "")
        done.informativeText = result.message
        done.runModal()
      } catch {
        showError(error, file: url)
      }

    default:
      break
    }
  }

  private static func showThemesSettings() {
    if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
       let browser = AppDelegate.shared.service.browsers[window.windowNumber] {
      browser.showSettings(category: .Theme)
    }
  }

  static func showError(_ error: Error, file: URL? = nil) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = file.map { String(format: NSLocalizedString("Couldn't open “%@”", comment: ""), $0.lastPathComponent) }
      ?? NSLocalizedString("Something went wrong", comment: "")
    alert.informativeText = error.localizedDescription
    alert.runModal()
  }
}
