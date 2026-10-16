//
//  SearchEditBox.swift
//  Ovra
//
//

import SwiftUI
import SwiftData

struct SearchEditBox: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) var modelContext

  @ObservedObject var service: Service
  @ObservedObject var browser: Browser
  @ObservedObject var tab: Tab
  
  var body: some View {
    VStack(spacing: 0) {
      if let searchBoxRect = browser.searchBoxRect {
        VStack(spacing: 0) {
          HStack(spacing: 0) {
            HStack(spacing: 0) {
              VStack(spacing: 0) {
                SearchAutoCompleteBox(service: service, browser: browser, tab: tab, tabWidth: CGFloat(searchBoxRect.width))
              }
              .frame(width: searchBoxRect.width)
            }
            .background(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tab.isEditSearch ? Color("ActiveInputBG") : Color.addressPill)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: Color(red: 0.08, green: 0.04, blue: 0.24).opacity(tab.isEditSearch ? (colorScheme == .dark ? 0.45 : 0.22) : 0.15), radius: tab.isEditSearch ? 14 : 8, x: 0, y: 2)
            Spacer()
          }
          Spacer()
        }
        .offset(x: searchBoxRect.minX, y: searchBoxRect.minY)
      }
    }
  }
}
