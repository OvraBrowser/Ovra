//
//  FavoriteItem.swift
//  Ovra
//
//

import SwiftUI

struct FavoriteItemView: View {
  @ObservedObject var browser: Browser
  @ObservedObject var tab: Tab
  let favorite: Favorite
  @Binding var editingFavorite: Favorite?
  @Binding var showEditDialog: Bool
  @Binding var showContextMenu: Favorite?
  
  @State private var isHovered = false
  @State private var showMenu = false
  @State private var isButtonHovered = false
  
  @AppStorage("selectedTheme") private var selectedTheme: String = Theme.bluePurple.rawValue
  // Observed so text colour updates when a custom theme is edited.
  @AppStorage("customThemes") private var customThemesData: Data = Data()

  var body: some View {
    VStack(spacing: 8) {
      Text(String(favorite.title.prefix(1).uppercased()))
        .font(.system(size: 28, weight: .bold))
        .foregroundColor(Color(red: 0.14, green: 0.16, blue: 0.18))
        .frame(width: 72, height: 72)
        .background(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.92))
        )
        .shadow(color: Color(red: 0.08, green: 0.04, blue: 0.24).opacity(0.2), radius: 9, y: 6)
        .scaleEffect(isHovered ? 1.04 : 1)
        .overlay(alignment: .topTrailing) {
          if isHovered {
            Button(action: {
              showMenu = true
              tab.isEditSearch = false
            }) {
              Image(systemName: "ellipsis")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(red: 0.14, green: 0.16, blue: 0.18))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.white))
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("Edit favorite", comment: ""))
            .offset(x: 6, y: -6)
          }
        }
        .popover(isPresented: $showMenu, arrowEdge: .top) {
          FavoriteContextMenu(
            favorite: favorite,
            editingFavorite: $editingFavorite,
            showEditDialog: $showEditDialog,
            showMenu: $showMenu
          )
        }

      Text(favorite.title)
        .font(.system(size: 12))
        .foregroundColor(ThemeForeground.color(for: selectedTheme))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: 96)
    }
    .frame(width: 96)
    .contentShape(Rectangle())
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovered = hovering
      }
    }
    .onTapGesture {
      // 즐겨찾기 클릭 시 해당 URL로 이동
      var urlString = favorite.address
      if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
        urlString = "https://\(urlString)"
      }
      
      if let url = URL(string: urlString) {
        if tab.isInit {
          tab.updateURLBySearch(url: url)
        } else {
          browser.newTab(url)
        }
      }
    }
  }
}
