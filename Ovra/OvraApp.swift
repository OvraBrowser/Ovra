//
//  OvraApp.swift
//  Ovra
//
//

import SwiftUI



@main
struct OvraApp: App {
  
  // Sparkle's updater lives in AppDelegate (one updater for the whole app).
  
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  var body: some Scene {
    Settings {
      EmptyView()
    }
    .commands {
      MainCommands(appDelegate: appDelegate)
      CleanCommands(appDelegate: appDelegate)
    }
  }
}
