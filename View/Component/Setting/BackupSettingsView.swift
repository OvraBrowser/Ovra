//
//  BackupSettingsView.swift
//  Ovra
//
//  Export / restore .ovrabackup files and share .ovratheme files.
//

import SwiftUI

struct BackupSettingsView: View {
  @ObservedObject var browser: Browser
  @AppStorage("customThemes") private var customThemesData: Data = Data()

  @State private var exportContents = BackupContents()
  @State private var pickedBackup: OvraBackup?
  @State private var restoreParts = BackupContents()
  @State private var restoreMessage: String?
  @State private var themeMessage: String?

  private var customThemes: [CustomTheme] { ThemeLibrary.decode(customThemesData) }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      SettingsPageHeader(
        title: NSLocalizedString("Backup & Import", comment: ""),
        subtitle: NSLocalizedString("Save Ovra to a file to keep it safe, move it to another Mac, or share your themes.", comment: "")
      )

      // ── Back up ──
      SettingsGroup(
        title: NSLocalizedString("Create a Backup", comment: ""),
        footer: NSLocalizedString("Saved as an .ovrabackup file. History, open tabs, cookies and site permissions aren't included.", comment: "")
      ) {
        SettingsToggleItem(title: NSLocalizedString("Settings", comment: ""),
                           subtitle: NSLocalizedString("Search engine, screen mode, history and blocking", comment: ""),
                           isOn: $exportContents.settings)
        SettingsDivider()
        SettingsToggleItem(title: NSLocalizedString("Themes", comment: ""),
                           subtitle: themesSubtitle,
                           isOn: $exportContents.appearance)
        SettingsDivider()
        SettingsToggleItem(title: NSLocalizedString("Favorites", comment: ""), isOn: $exportContents.favorites)
        SettingsDivider()
        SettingsToggleItem(title: NSLocalizedString("Bookmarks", comment: ""),
                           subtitle: NSLocalizedString("Including folders", comment: ""),
                           isOn: $exportContents.bookmarks)
        SettingsDivider()
        SettingsItem(title: "") {
          Button {
            OvraFileManager.exportBackup(exportContents)
          } label: {
            Label(NSLocalizedString("Export Backup…", comment: ""), systemImage: "square.and.arrow.up")
          }
          .buttonStyle(SettingsPillButtonStyle(prominent: true))
          .disabled(exportContents.isEmpty)
          .opacity(exportContents.isEmpty ? 0.5 : 1)
        }
      }

      // ── Restore ──
      SettingsGroup(
        title: NSLocalizedString("Restore", comment: ""),
        footer: NSLocalizedString("Settings and the active theme are replaced. Favorites, bookmarks and custom themes are added to what you already have — duplicates are skipped.", comment: "")
      ) {
        if let backup = pickedBackup {
          SettingsItem(
            title: String(format: NSLocalizedString("Backup from %@", comment: ""), backup.createdAt.formatted(date: .abbreviated, time: .shortened)),
            subtitle: [backup.deviceName, backup.appVersion.isEmpty ? nil : "Ovra \(backup.appVersion)"]
              .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
          ) {
            Button(NSLocalizedString("Choose Another…", comment: "")) { pickBackup() }
              .buttonStyle(SettingsPillButtonStyle())
          }
          if backup.settings != nil {
            SettingsDivider()
            SettingsToggleItem(title: NSLocalizedString("Settings", comment: ""), isOn: $restoreParts.settings)
          }
          if let appearance = backup.appearance {
            SettingsDivider()
            SettingsToggleItem(title: NSLocalizedString("Themes", comment: ""),
                               subtitle: String(format: NSLocalizedString("%d custom themes", comment: ""), appearance.customThemes.count),
                               isOn: $restoreParts.appearance)
          }
          if let favorites = backup.favorites {
            SettingsDivider()
            SettingsToggleItem(title: NSLocalizedString("Favorites", comment: ""),
                               subtitle: String(format: NSLocalizedString("%d favorites", comment: ""), favorites.count),
                               isOn: $restoreParts.favorites)
          }
          if let bookmarks = backup.bookmarks {
            SettingsDivider()
            SettingsToggleItem(title: NSLocalizedString("Bookmarks", comment: ""),
                               subtitle: String(format: NSLocalizedString("%d bookmarks", comment: ""), bookmarks.bookmarkCount),
                               isOn: $restoreParts.bookmarks)
          }
          SettingsDivider()
          SettingsItem(title: "") {
            HStack(spacing: 8) {
              Button(NSLocalizedString("Cancel", comment: "")) {
                withAnimation { pickedBackup = nil }
              }
              .buttonStyle(SettingsPillButtonStyle())
              Button(NSLocalizedString("Restore", comment: "")) { restore(backup) }
                .buttonStyle(SettingsPillButtonStyle(prominent: true))
                .disabled(restoreParts.isEmpty)
                .opacity(restoreParts.isEmpty ? 0.5 : 1)
            }
          }
        } else {
          SettingsItem(
            title: NSLocalizedString("Restore from a backup file", comment: ""),
            subtitle: NSLocalizedString("You can also double-click an .ovrabackup file in Finder.", comment: "")
          ) {
            Button {
              pickBackup()
            } label: {
              Label(NSLocalizedString("Choose File…", comment: ""), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(SettingsPillButtonStyle())
          }
        }
        if let restoreMessage {
          SettingsDivider()
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(Color(hex: "#30D158"))
            Text(restoreMessage)
              .font(.system(size: 12))
              .foregroundColor(Color("UIText"))
              .fixedSize(horizontal: false, vertical: true)
            Spacer()
          }
          .padding(14)
        }
      }

      // ── Themes ──
      SettingsGroup(
        title: NSLocalizedString("Share Themes", comment: ""),
        footer: NSLocalizedString("Theme files end in .ovratheme. Anyone with Ovra can double-click one to add it.", comment: "")
      ) {
        SettingsItem(title: NSLocalizedString("Import themes", comment: "")) {
          Button(NSLocalizedString("Import…", comment: "")) {
            let added = OvraFileManager.importThemesWithPanel()
            if !added.isEmpty {
              withAnimation {
                themeMessage = String(format: NSLocalizedString("Imported %d themes.", comment: ""), added.count)
              }
            }
          }
          .buttonStyle(SettingsPillButtonStyle())
        }
        SettingsDivider()
        SettingsItem(title: NSLocalizedString("Export all custom themes", comment: ""),
                     subtitle: customThemes.isEmpty ? NSLocalizedString("You haven't made any custom themes yet.", comment: "") : nil) {
          Button(NSLocalizedString("Export…", comment: "")) {
            OvraFileManager.exportThemes(customThemes)
          }
          .buttonStyle(SettingsPillButtonStyle())
          .disabled(customThemes.isEmpty)
          .opacity(customThemes.isEmpty ? 0.5 : 1)
        }
        if let themeMessage {
          SettingsDivider()
          SettingsButtonItem(title: themeMessage, subtitle: NSLocalizedString("Open Themes to use them", comment: "")) {
            browser.selectedSettingsCategory = .Theme
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private var themesSubtitle: String {
    let count = customThemes.count
    return count == 0
      ? NSLocalizedString("Your active theme", comment: "")
      : String(format: NSLocalizedString("Your active theme and %d custom themes", comment: ""), count)
  }

  private func pickBackup() {
    guard let backup = OvraFileManager.pickBackup() else { return }
    withAnimation {
      restoreMessage = nil
      restoreParts = BackupContents(available: backup)
      pickedBackup = backup
    }
  }

  private func restore(_ backup: OvraBackup) {
    let result = OvraFileManager.restore(backup, parts: restoreParts)
    withAnimation {
      restoreMessage = result.message
      pickedBackup = nil
    }
  }
}
