//
//  SettingsComponents.swift
//  Ovra
//
//  Building blocks for the Settings pages: grouped cards, rows, icon badges.
//

import SwiftUI

extension Color {
  static let settingsPage = Color.adaptive(
    light: NSColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1),
    dark: NSColor(red: 0.118, green: 0.118, blue: 0.125, alpha: 1)
  )
  static let settingsSidebar = Color.adaptive(
    light: NSColor(red: 0.91, green: 0.91, blue: 0.929, alpha: 0.9),
    dark: NSColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 0.9)
  )
  static let settingsCard = Color.adaptive(
    light: NSColor.white,
    dark: NSColor(red: 0.19, green: 0.19, blue: 0.2, alpha: 1)
  )
  static let settingsAccent = Color(hex: "#5E5CE6")
}

/// Big page title with an optional line under it.
struct SettingsPageHeader: View {
  let title: String
  var subtitle: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.system(size: 22, weight: .semibold))
        .foregroundColor(Color("UIText"))
      if let subtitle {
        Text(subtitle)
          .font(.system(size: 13))
          .foregroundColor(Color("UIText").opacity(0.6))
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A titled white card holding rows. Put `SettingsDivider()` between rows.
struct SettingsGroup<Content: View, Accessory: View>: View {
  var title: String?
  var footer: String?
  var accessory: Accessory
  var content: Content

  init(title: String? = nil, footer: String? = nil,
       @ViewBuilder content: () -> Content,
       @ViewBuilder accessory: () -> Accessory) {
    self.title = title
    self.footer = footer
    self.content = content()
    self.accessory = accessory()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if title != nil || !(accessory is EmptyView) {
        HStack(alignment: .firstTextBaseline) {
          if let title {
            Text(title)
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(Color("UIText"))
          }
          Spacer()
          accessory
        }
        .padding(.horizontal, 2)
      }

      VStack(spacing: 0) {
        content
      }
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color.settingsCard)
          .shadow(color: .black.opacity(0.08), radius: 0.5)
      )

      if let footer {
        Text(footer)
          .font(.system(size: 11))
          .foregroundColor(Color("UIText").opacity(0.55))
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 2)
      }
    }
  }
}

extension SettingsGroup where Accessory == EmptyView {
  init(title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.footer = footer
    self.accessory = EmptyView()
    self.content = content()
  }
}

struct SettingsDivider: View {
  var body: some View {
    Rectangle()
      .fill(Color("UIText").opacity(0.1))
      .frame(height: 0.5)
      .padding(.leading, 14)
  }
}

/// Title (+ optional explanation) on the left, a control on the right.
struct SettingsItem<Control: View>: View {
  let title: String
  var subtitle: String? = nil
  @ViewBuilder var control: Control

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 13))
          .foregroundColor(Color("UIText"))
        if let subtitle {
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundColor(Color("UIText").opacity(0.55))
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 12)
      control
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(minHeight: 44)
  }
}

/// A toggle row.
struct SettingsToggleItem: View {
  let title: String
  var subtitle: String? = nil
  @Binding var isOn: Bool

  var body: some View {
    SettingsItem(title: title, subtitle: subtitle) {
      Toggle(title, isOn: $isOn)
        .toggleStyle(.switch)
        .labelsHidden()
        .controlSize(.small)
        .tint(.settingsAccent)
    }
  }
}

/// A full-width tappable row (navigation or action).
struct SettingsButtonItem: View {
  let title: String
  var subtitle: String? = nil
  var icon: String = "chevron.right"
  var role: ButtonRole? = nil
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 13))
            .foregroundColor(role == .destructive ? Color(hex: "#D70015") : Color("UIText"))
          if let subtitle {
            Text(subtitle)
              .font(.system(size: 11))
              .foregroundColor(Color("UIText").opacity(0.55))
          }
        }
        Spacer()
        Image(systemName: icon)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(Color("UIText").opacity(0.35))
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .frame(minHeight: 44)
      .background(Color("UIText").opacity(isHovered ? 0.04 : 0))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}

/// Small rounded square with a white symbol, like System Settings.
struct SettingsIconBadge: View {
  let symbol: String
  let colors: [Color]
  var size: CGFloat = 20

  var body: some View {
    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
      .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
      .frame(width: size, height: size)
      .overlay(
        Image(systemName: symbol)
          .font(.system(size: size * 0.55, weight: .semibold))
          .foregroundColor(.white)
      )
      .accessibilityHidden(true)
  }
}

/// Compact bordered button used inside rows.
struct SettingsPillButtonStyle: ButtonStyle {
  var prominent = false
  var destructive = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .medium))
      .foregroundColor(prominent ? .white : (destructive ? Color(hex: "#D70015") : Color("UIText")))
      .padding(.horizontal, 12)
      .frame(height: 26)
      .background(
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(prominent ? Color.settingsAccent : Color.settingsCard)
          .shadow(color: .black.opacity(prominent ? 0 : 0.15), radius: 0.5)
          .shadow(color: .black.opacity(prominent ? 0 : 0.06), radius: 1, y: 1)
      )
      .opacity(configuration.isPressed ? 0.75 : 1)
      .contentShape(Rectangle())
  }
}
