//
//  SearchHistory.swift
//  Ovra
//
//

import SwiftUI
import SwiftData

@Model
class SearchHistory: Identifiable  {
  @Attribute(.unique)
  var id: UUID
  
  @Relationship var searchHistoryGroup: SearchHistoryGroup?
  
  var createDate: Date
  
  init(searchHistoryGroup: SearchHistoryGroup) {
    self.id = UUID()
    self.searchHistoryGroup = searchHistoryGroup
    self.createDate = Date.now
    searchHistoryGroup.updateDate = Date.now
  }
}
