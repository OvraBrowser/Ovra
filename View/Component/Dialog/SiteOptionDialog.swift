//
//  SiteOptionDialog.swift
//  Ovra
//
//

import SwiftUI
import SwiftData
import UserNotifications

struct SiteOptionDialog: View {
  @Query var generalSetting: [GeneralSetting]
  
  @ObservedObject var service: Service
  @ObservedObject var browser: Browser
  @ObservedObject var tab: Tab
  @Binding var isSiteDialog: Bool
  
  @State var cacheBlockingLevel: String?
  
  init(service: Service, browser: Browser, tab: Tab, isSiteDialog: Binding<Bool>) {
    self.service = service
    self.tab = tab
    self.browser = browser
    self._isSiteDialog = isSiteDialog
    self._cacheBlockingLevel = State(initialValue: service.blockingLevel)
  }
  
  private var host: String {
    if tab.originURL.scheme == "ovra" || tab.originURL.absoluteString == "about:blank" {
      return "Ovra"
    }
    return tab.originURL.host() ?? tab.printURL
  }

  private var isInsecure: Bool { tab.isValidCertificate == false }
  private var usesStorage: Bool { tab.localStorage != "{}" || tab.sessionStorage != "{}" }
  private var hasSiteData: Bool { usesStorage || tab.cookies.count > 0 }

  private var statusTitle: String {
    if isInsecure { return NSLocalizedString("Not Secure", comment: "") }
    return service.isTrackerBlocking
      ? NSLocalizedString("Protected", comment: "")
      : NSLocalizedString("Protection Off", comment: "")
  }

  private var badgeColors: [Color] {
    if isInsecure { return [Color(hex: "#FF9F0A"), Color(hex: "#D9480F")] }
    if !service.isTrackerBlocking { return [Color(hex: "#8E8E93"), Color(hex: "#5C5C61")] }
    return [Color(hex: "#6E62E8"), Color(hex: "#4B3FC0")]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack(spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LinearGradient(colors: badgeColors, startPoint: .topLeading, endPoint: .bottomTrailing))
          Image(systemName: isInsecure ? "exclamationmark.shield.fill" : (service.isTrackerBlocking ? "checkmark.shield.fill" : "shield.slash.fill"))
            .font(.system(size: 19, weight: .semibold))
            .foregroundColor(.white)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 2) {
          Text(statusTitle)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Color("UIText"))
          Text(host)
            .font(.system(size: 12))
            .foregroundColor(Color("UIText").opacity(0.6))
            .lineLimit(1)
            .truncationMode(.middle)
        }
        Spacer(minLength: 0)
      }

      // Stat tiles
      HStack(spacing: 8) {
        PrivacyStatTile(value: "\(tab.cookies.count)", label: NSLocalizedString("Cookies", comment: ""))
        PrivacyStatTile(value: usesStorage ? NSLocalizedString("Used", comment: "") : NSLocalizedString("None", comment: ""),
                        label: NSLocalizedString("Web Storage", comment: ""))
        PrivacyStatTile(icon: isInsecure ? "lock.open.fill" : "lock.fill",
                        iconColor: isInsecure ? Color("AlertText") : Color("UIText"),
                        label: isInsecure ? NSLocalizedString("Not Secure", comment: "") : NSLocalizedString("Secure", comment: ""))
      }
      .padding(.top, 16)

      // Settings card
      VStack(spacing: 0) {
        HStack {
          Text(NSLocalizedString("Block ads and trackers", comment: ""))
            .font(.system(size: 13))
            .foregroundColor(Color("UIText"))
          Spacer()
          Toggle("", isOn: $service.isTrackerBlocking)
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
            .tint(Color(hex: "#34C759"))
            .accessibilityLabel(NSLocalizedString("Block ads and trackers", comment: ""))
        }
        .padding(.horizontal, 12)
        .frame(height: 42)

        Divider().padding(.leading, 12)

        PrivacyCardRow(title: NSLocalizedString("Clear cookies and storage", comment: ""),
                       icon: "trash",
                       isDestructive: true,
                       isEnabled: hasSiteData) {
          DispatchQueue.main.async {
            tab.isClearCookieNStorage = true
            self.isSiteDialog = false
            AppDelegate.shared.refreshTab()
          }
        }

        Divider().padding(.leading, 12)

        PrivacyCardRow(title: NSLocalizedString("How blocking works", comment: ""), icon: "chevron.right") {
          browser.newTab(URL(string: "https://github.com/OvraBrowser/Ovra/tree/main/Packages/ContentBlockRuleList")!)
          self.isSiteDialog = false
        }
      }
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color.glassSelection)
          .shadow(color: .black.opacity(0.06), radius: 0.5)
      )
      .padding(.top, 14)

      if !tab.certificateSummary.isEmpty && !isInsecure {
        Text(tab.certificateSummary)
          .font(.system(size: 11))
          .foregroundColor(Color("UIText").opacity(0.55))
          .lineLimit(2)
          .padding(.top, 8)
          .padding(.horizontal, 4)
      }

      // Quick actions
      HStack(spacing: 8) {
        PrivacyActionButton(icon: "link", title: NSLocalizedString("Copy Link", comment: "")) {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(tab.originURL.absoluteString, forType: .string)
          self.isSiteDialog = false
        }
        PrivacyActionButton(text: "\(Int((tab.zoomLevel * 100).rounded()))%", title: NSLocalizedString("Zoom", comment: "")) {
          self.isSiteDialog = false
          DispatchQueue.main.async { tab.isZoomDialog = true }
        }
        PrivacyActionButton(icon: "gearshape", title: NSLocalizedString("Site Settings", comment: "")) {
          self.isSiteDialog = false
          browser.showSettings(category: .permissions)
        }
      }
      .padding(.top, 12)
    }
    .padding(18)
    .frame(width: 340)
    .onChange(of: service.isTrackerBlocking) { oV, nV in
      if let generalSetting = generalSetting.first {
        generalSetting.isTrackerBlocking = nV
      }
    }
  }
}

// MARK: - Pieces

private struct PrivacyStatTile: View {
  var value: String? = nil
  var icon: String? = nil
  var iconColor: Color = Color("UIText")
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let icon {
        Image(systemName: icon)
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(iconColor)
          .frame(height: 26, alignment: .leading)
      } else if let value {
        Text(value)
          .font(.system(size: 22, weight: .bold))
          .foregroundColor(Color("UIText"))
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .frame(height: 26, alignment: .leading)
      }
      Text(label)
        .font(.system(size: 11))
        .foregroundColor(Color("UIText").opacity(0.6))
        .lineLimit(1)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.glassSelection)
        .shadow(color: .black.opacity(0.06), radius: 0.5)
    )
  }
}

private struct PrivacyCardRow: View {
  let title: String
  let icon: String
  var isDestructive: Bool = false
  var isEnabled: Bool = true
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack {
        Text(title)
          .font(.system(size: 13))
          .foregroundColor(isDestructive ? Color("AlertText") : Color("UIText"))
        Spacer()
        Image(systemName: icon)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(Color("UIText").opacity(0.4))
      }
      .padding(.horizontal, 12)
      .frame(height: 40)
      .background(Color("UIText").opacity(isHovered && isEnabled ? 0.05 : 0))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.45)
    .onHover { isHovered = $0 }
  }
}

private struct PrivacyActionButton: View {
  var icon: String? = nil
  var text: String? = nil
  let title: String
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        if let icon {
          Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .frame(height: 18)
        } else if let text {
          Text(text)
            .font(.system(size: 15, weight: .semibold))
            .frame(height: 18)
        }
        Text(title)
          .font(.system(size: 11))
      }
      .foregroundColor(Color("UIText"))
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color("UIText").opacity(isHovered ? 0.12 : 0.07))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}
