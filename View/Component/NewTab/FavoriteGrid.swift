//
//  FavoriteGrid.swift
//  Ovra
//
//

import SwiftUI
import SwiftData

struct FavoriteGrid: View {
  let favorites: [Favorite]
  @ObservedObject var browser: Browser
  @ObservedObject var tab: Tab
  @Binding var editingFavorite: Favorite?
  @Binding var showEditDialog: Bool
  @Binding var showContextMenu: Favorite?
  let maxFavorites: Int
  let containerWidth: CGFloat
  
  private let columns = [GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 18)]

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
      ForEach(favorites.prefix(maxFavorites)) { favorite in
        FavoriteItemView(
          browser: browser,
          tab: tab,
          favorite: favorite,
          editingFavorite: $editingFavorite,
          showEditDialog: $showEditDialog,
          showContextMenu: $showContextMenu
        )
      }
      if favorites.count < maxFavorites {
        AddFavoriteButton(showEditDialog: $showEditDialog, editingFavorite: $editingFavorite)
      }
    }
  }
}
