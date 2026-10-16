//
//  SwiftUIView.swift
//  Ovra
//
//

import SwiftUI

struct HistoryKeyButton: View {
  @ObservedObject var tab: Tab
  var isBack: Bool
  
  @AppStorage("selectedTheme") private var selectedTheme: String = Theme.bluePurple.rawValue
  // Observed so text colour updates when a custom theme is edited.
  @AppStorage("customThemes") private var customThemesData: Data = Data()
  @State private var isBackForwardHover: Bool = false
  
  var body: some View {
    let icon = isBack ? "chevron.backward" : "chevron.forward"
    let isBackForward = isBack ? tab.isBack : tab.isForward
    let tint = ThemeForeground.color(for: selectedTheme)
    
    Image(systemName: icon)
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(tint.opacity(isBackForward ? 1 : 0.45))
      .frame(width: 40, height: 36)
      .background(
        Capsule(style: .continuous)
          .fill(tint.opacity(isBackForwardHover && isBackForward ? 0.16 : 0))
          .padding(3)
      )
      .onHover { hovering in
        withAnimation(.easeInOut(duration: 0.12)) {
          isBackForwardHover = hovering
        }
      }
  }
}
