//
//  OvraWindowDelegate.swift
//  Ovra
//
//

import SwiftUI

class OvraWindowDelegate: NSObject, NSWindowDelegate, ObservableObject {
  var windowMap: [UUID:NSWindow] = [:]
  @Published var isFullScreen: Bool = false
  var lastActivationTime: Date?
  
  func windowWillEnterFullScreen(_ notification: Notification) {
    AppDelegate.shared.isFullScreenMode = true
    DispatchQueue.main.async {
      self.isFullScreen = true
    }
  }
  
  func windowDidEnterFullScreen(_ notification: Notification) {
  }
  
  func windowWillExitFullScreen(_ notification: Notification) {
    AppDelegate.shared.isFullScreenMode = false
    DispatchQueue.main.async {
      self.isFullScreen = false
    }
  }

  func windowDidExitFullScreen(_ notification: Notification) {
    if let window = notification.object as? NSWindow {
      OvraWindowDelegate.layoutTrafficLights(window)
    }
  }

  func windowDidResize(_ notification: Notification) {
    if let window = notification.object as? NSWindow {
      OvraWindowDelegate.layoutTrafficLights(window)
    }
  }

  func windowDidBecomeKey(_ notification: Notification) {
    if let window = notification.object as? NSWindow {
      OvraWindowDelegate.layoutTrafficLights(window)
    }
  }

  /// Height of Ovra's toolbar row; the traffic lights are centred in it.
  static let titlebarHeight: CGFloat = 52

  /// Moves the close/minimise/zoom buttons down so they sit centred in the
  /// 52pt toolbar row (inside the sidebar header). AppKit lays the titlebar
  /// out again on resize/focus changes, so a TrafficLightPositioner re-applies
  /// it whenever those views move.
  static func layoutTrafficLights(_ window: NSWindow) {
    TrafficLightPositioner.attach(to: window)
  }

  func windowWillClose(_ notification: Notification) {
    print("windowWillClose")
    guard let window = notification.object as? NSWindow else { return }
    let frameString = NSStringFromRect(window.frame)
    UserDefaults.standard.set(frameString, forKey: "lastWindowFrame")
  }
  
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    print("windowShouldClose")
    let windowNumber = sender.windowNumber
    if let browser = AppDelegate.shared.service.browsers[windowNumber] {
      let tabs = browser.tabs
      for tab in tabs {
        AppDelegate.shared.closeInspector(tab.id)
      }
      browser.closeAllTab {
        browser.tabs = []
        AppDelegate.shared.service.browsers[windowNumber] = nil
        sender.close()
      }
      return false
    } else {
      return true
    }
  }
}

/// Keeps the traffic lights centred in Ovra's 52pt toolbar row.
final class TrafficLightPositioner {
  private static var positioners: [ObjectIdentifier: TrafficLightPositioner] = [:]

  private weak var window: NSWindow?
  private var observers: [NSObjectProtocol] = []
  private var isApplying = false

  static func attach(to window: NSWindow) {
    let key = ObjectIdentifier(window)
    if let existing = positioners[key] {
      existing.apply()
      return
    }
    let positioner = TrafficLightPositioner(window: window)
    positioners[key] = positioner
    positioner.apply()
    DispatchQueue.main.async { positioner.apply() }
  }

  private init(window: NSWindow) {
    self.window = window
    guard let close = window.standardWindowButton(.closeButton),
          let titlebarView = close.superview,
          let container = titlebarView.superview else { return }

    let watched: [NSView] = [container, titlebarView, close]
    for view in watched {
      view.postsFrameChangedNotifications = true
      observers.append(NotificationCenter.default.addObserver(
        forName: NSView.frameDidChangeNotification, object: view, queue: .main
      ) { [weak self] _ in
        self?.apply()
      })
    }
    observers.append(NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification, object: window, queue: .main
    ) { [weak self] _ in
      self?.detach()
    })
  }

  private func detach() {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    observers = []
    if let window { TrafficLightPositioner.positioners[ObjectIdentifier(window)] = nil }
  }

  func apply() {
    guard !isApplying,
          let window,
          !window.styleMask.contains(.fullScreen),
          let close = window.standardWindowButton(.closeButton),
          let titlebarView = close.superview,
          let container = titlebarView.superview else { return }
    isApplying = true
    defer { isApplying = false }

    let height = OvraWindowDelegate.titlebarHeight
    let containerFrame = NSRect(x: container.frame.minX,
                                y: window.frame.height - height,
                                width: container.frame.width,
                                height: height)
    if container.frame != containerFrame { container.frame = containerFrame }
    let titlebarFrame = NSRect(origin: .zero, size: containerFrame.size)
    if titlebarView.frame != titlebarFrame { titlebarView.frame = titlebarFrame }

    let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
    for (index, type) in buttons.enumerated() {
      guard let button = window.standardWindowButton(type) else { continue }
      let origin = NSPoint(x: 22 + CGFloat(index) * 20,
                           y: ((height - button.frame.height) / 2).rounded())
      if button.frame.origin != origin { button.setFrameOrigin(origin) }
    }
  }
}
