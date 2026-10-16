//
//  VisitHistory.swift
//  Ovra
//
//

import SwiftUI
import SwiftData

@Model
class VisitHistory {
  @Attribute(.unique)
  var id: UUID
  
  @Relationship var visitHistoryGroup: VisitHistoryGroup?
  
  var createDate: Date
  
  init(visitHistoryGroup: VisitHistoryGroup) {
    self.id = UUID()
    self.visitHistoryGroup = visitHistoryGroup
    self.createDate = Date.now
    visitHistoryGroup.updateDate = Date.now
  }
}

