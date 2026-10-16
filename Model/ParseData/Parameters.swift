//
//  Parameters.swift
//  Ovra
//
//

import SwiftUI

class UpdatePermissionParams: Codable {
  var id: String
  var isDenied: Bool
  
  init(id: String, isDenied: Bool) {
    self.id = id
    self.isDenied = isDenied
  }
}
