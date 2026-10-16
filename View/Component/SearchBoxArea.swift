//
//  SearchBox.swift
//  Ovra
//
//

import SwiftUI

struct SearchBoxArea: View {
  @ObservedObject var browser: Browser
  
  var body: some View {
    VStack(spacing: 0) {
      GeometryReader { geometry in
        VStack(spacing: 0) { }
        .frame(maxWidth: .infinity, maxHeight: 36)
        .onAppear {
          browser.searchBoxRect = geometry.frame(in: .global)
        }
        .onChange(of: geometry.frame(in: .global)) { _, newValue in
          browser.searchBoxRect = newValue
        }
      }
    }
    .frame(height: 36)
  }
}
  
