//
//  GlassControls.swift
//  Ovra
//
//  Shared pieces of the floating "glass" chrome: capsule button groups,
//  toolbar icon buttons and the frosted panel background.
//

import SwiftUI

extension Color {
  /// Light-mode / dark-mode pair, resolved by the current NSAppearance.
  static func adaptive(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    })
  }

  /// Frosted sidebar / popover panel fill.
  static let glassPanel = Color.adaptive(
    light: NSColor(red: 0.965, green: 0.965, blue: 0.98, alpha: 0.78),
    dark: NSColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 0.78)
  )

  /// Selected row inside a glass panel (the "white chip" of the active tab).
  static let glassSelection = Color.adaptive(
    light: NSColor.white,
    dark: NSColor(white: 1, alpha: 0.14)
  )

  /// Address pill fill.
  static let addressPill = Color.adaptive(
    light: NSColor(white: 1, alpha: 0.94),
    dark: NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 0.94)
  )

  /// Privacy badge inside the address pill.
  static let privacyBadgeBG = Color.adaptive(
    light: NSColor(red: 0.914, green: 0.906, blue: 0.984, alpha: 1),
    dark: NSColor(red: 0.36, green: 0.33, blue: 0.75, alpha: 0.35)
  )
  static let privacyBadgeText = Color.adaptive(
    light: NSColor(red: 0.294, green: 0.247, blue: 0.753, alpha: 1),
    dark: NSColor(red: 0.74, green: 0.72, blue: 1, alpha: 1)
  )
}

/// Frosted, rounded panel used by the sidebar and the start-page cards.
struct GlassPanelBackground: View {
  var cornerRadius: CGFloat = 20

  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color.glassPanel)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
      )
      .shadow(color: Color(red: 0.08, green: 0.04, blue: 0.24).opacity(0.18), radius: 20, y: 6)
  }
}

/// Translucent capsule that groups toolbar buttons (back/forward, actions).
struct GlassCapsule<Content: View>: View {
  var tint: Color = .white
  @ViewBuilder var content: Content

  var body: some View {
    HStack(spacing: 0) {
      content
    }
    .frame(height: 36)
    .background(
      Capsule(style: .continuous)
        .fill(tint.opacity(0.22))
        .overlay(
          Capsule(style: .continuous)
            .strokeBorder(tint.opacity(0.18), lineWidth: 0.5)
        )
    )
  }
}

/// Icon button that sits inside a GlassCapsule.
struct GlassToolbarButton: View {
  let icon: String
  let label: String
  var tint: Color = .white
  var isEnabled: Bool = true
  var isActive: Bool = false
  var badge: Bool = false
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      ZStack(alignment: .topTrailing) {
        Image(systemName: icon)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(tint.opacity(isEnabled ? 1 : 0.5))
          .frame(width: 40, height: 36)
          .background(
            Capsule(style: .continuous)
              .fill(tint.opacity((isHovered && isEnabled) || isActive ? 0.16 : 0))
              .padding(3)
          )
          .contentShape(Rectangle())

        if badge {
          Circle()
            .fill(Color.accentColor)
            .frame(width: 7, height: 7)
            .offset(x: -9, y: 8)
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .help(label)
    .accessibilityLabel(label)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
    }
  }
}
