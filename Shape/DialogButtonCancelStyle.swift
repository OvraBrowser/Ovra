//
//  DialogButtonCancelStyle.swift
//  Ovra
//
//

import SwiftUI

struct DialogButtonCancelStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(.white)
      .font(.system(size: 12))
      .padding(.horizontal, 15)
      .padding(.vertical, 6)
      .background(configuration.isPressed ? Color("ButtonCancelBGHover") : Color("ButtonCancelBG"))
      .cornerRadius(5)
  }
}
