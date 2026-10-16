//
//  BasicObject.swift
//  Ovra
//
//

import SwiftUI

class SettingListItem: Codable {
  var id: String
  var name: String
  
  init(id: String, name: String) {
    self.id = id
    self.name = name
  }
}
