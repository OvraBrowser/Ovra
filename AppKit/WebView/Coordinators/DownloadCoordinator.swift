//
//  DownloadCoordinator.swift
//  Ovra
//
//

import SwiftUI
import WebKit

/// Hands downloads started in a web view to the app-wide DownloadManager,
/// which outlives the tab (see DownloadManager for why).
class DownloadCoordinator: NSObject {
  var parent: MainWebView!
  
  init(parent: MainWebView) {
    self.parent = parent
    super.init()
  }
  
  func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
    DownloadManager.shared.attach(download)
  }
  
  func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
    DownloadManager.shared.attach(download)
  }
}
