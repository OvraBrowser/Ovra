//
//  ProfileManager.swift
//  Ovra
//
//  The local Ovra profile (just a name for now — Ovra accounts with sync come
//  later) and "Reset Ovra", which returns the app to a fresh install.
//

import SwiftUI
import SwiftData
import WebKit

enum LocalProfile {
  /// UserDefaults key; views read it with @AppStorage so they update live.
  static let nameKey = "profileName"

  static var name: String {
    get { UserDefaults.standard.string(forKey: nameKey) ?? "" }
    set {
      let trimmed = String(newValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
      UserDefaults.standard.set(trimmed, forKey: nameKey)
    }
  }

  /// The saved name, or the Mac user's first name until one is set.
  static func displayName(_ stored: String) -> String {
    let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { return trimmed }
    return NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName()
  }

  static func firstName(_ stored: String) -> String {
    displayName(stored).split(separator: " ").first.map(String.init) ?? displayName(stored)
  }

  static func initial(_ stored: String) -> String {
    String(displayName(stored).prefix(1)).uppercased()
  }
}

@MainActor
enum ResetManager {
  /// Erases everything Ovra stores and relaunches into onboarding.
  /// Downloaded files in ~/Downloads are left alone.
  static func resetEverything() async {
    // 1. Close every window's tabs so web views stop writing.
    for window in NSApp.windows { window.orderOut(nil) }

    // 2. Website data: cookies, caches, local storage, service workers…
    let store = WKWebsiteDataStore.default()
    await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)

    // 3. Database: bookmarks, favorites, history, permissions, settings.
    let context = AppDelegate.shared.modelContainer.mainContext
    try? context.delete(model: Bookmark.self)
    try? context.delete(model: BookmarkGroup.self)
    try? context.delete(model: Favorite.self)
    try? context.delete(model: SearchHistory.self)
    try? context.delete(model: SearchHistoryGroup.self)
    try? context.delete(model: VisitHistory.self)
    try? context.delete(model: VisitHistoryGroup.self)
    try? context.delete(model: DomainPermission.self)
    try? context.delete(model: GeneralSetting.self)
    try? context.save()

    // 4. Preferences: themes, profile, onboarding, window size, language…
    if let bundleID = Bundle.main.bundleIdentifier {
      UserDefaults.standard.removePersistentDomain(forName: bundleID)
      UserDefaults.standard.synchronize()
    }

    // 5. Downloads list (files stay on disk).
    DownloadManager.shared.clearAll()

    relaunch()
  }

  private static func relaunch() {
    let path = Bundle.main.bundlePath
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    // Wait for this process to quit, then open a fresh copy.
    task.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"\(path)\""]
    try? task.run()
    // Skip the normal quit path, which would save window state again.
    exit(0)
  }
}
