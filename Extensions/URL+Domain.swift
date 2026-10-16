//
//  URL+Domain.swift
//  Ovra
//
//

import Foundation

extension URL {
  var mainDomain: String? {
    guard let host = self.host else { return nil }
    return host
  }
}
