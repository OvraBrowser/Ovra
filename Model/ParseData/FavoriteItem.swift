//
//  FavoriteItem.swift
//  Ovra
//
//

import SwiftUI

class FavoriteItem: Codable {
  var id: UUID
  var title: String
  var address: String
  
  init(id: UUID, title: String, address: String) {
    self.id = id
    self.title = title
    self.address = address
  }
}


class FavoriteItemParams: Codable {
  var title: String
  var address: String
  
  init(title: String, address: String) {
    self.title = title
    self.address = address
  }
}
