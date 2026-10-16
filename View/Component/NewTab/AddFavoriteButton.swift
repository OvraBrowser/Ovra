//
//  AddFavoriteButton.swift
//  Ovra
//
//

import  SwiftUI

struct AddFavoriteButton: View {
  @Binding var showEditDialog: Bool
  @Binding var editingFavorite: Favorite?
  
  @State private var isHovered = false
  @AppStorage("selectedTheme") private var selectedTheme: String = Theme.bluePurple.rawValue
  // Observed so text colour updates when a custom theme is edited.
  @AppStorage("customThemes") private var customThemesData: Data = Data()

  var body: some View {
    let foreground = ThemeForeground.color(for: selectedTheme)
    Button(action: {
      editingFavorite = nil
      showEditDialog = true
    }) {
      VStack(spacing: 8) {
        Image(systemName: "plus")
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(foreground)
          .frame(width: 72, height: 72)
          .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(foreground.opacity(isHovered ? 0.22 : 0.14))
              .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .strokeBorder(foreground.opacity(0.3), lineWidth: 1)
              )
          )
        Text(NSLocalizedString("Add", comment: ""))
          .font(.system(size: 12))
          .foregroundColor(foreground)
      }
      .frame(width: 96)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovered = hovering
      }
    }
  }
}
