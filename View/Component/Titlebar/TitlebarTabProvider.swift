//
//  TitlebarTabProvider.swift
//  Ovra
//
//

import SwiftUI

struct TitlebarTabProvider: View {
  @ObservedObject var service: Service
  @ObservedObject var browser: Browser
  
  @Binding var tabs: [Tab]
  @Binding var activeTabId: UUID?
  @Binding var isFullScreen: Bool
  
  var body: some View {
    WindowTitleBarView(service: service, browser: browser, tabs: $browser.tabs, activeTabId: $browser.activeTabId, isFullScreen: isFullScreen)
  }
}

