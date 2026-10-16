//
//  VisualEffect.swift
//  Ovra
//
//

import SwiftUI

struct VisualEffectNSView: NSViewRepresentable {
    func makeNSView(context: Self.Context) -> NSView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { }
}
