//
//  SharedGradientBackground.swift
//  Ovra
//
//  Created by Kilian Balaguer on 23/06/2025.
//


import SwiftUI

struct SharedGradientBackground: View {
    @AppStorage("selectedTheme") private var selectedTheme: String = Theme.bluePurple.rawValue
    @AppStorage("customThemes") private var customThemesData: Data = Data()

    private var currentGradient: LinearGradient {
        ThemeEffects.resolve(selectedTheme: selectedTheme, customThemesData: customThemesData).gradient
    }

    var offset: CGFloat

    var body: some View {
        currentGradient
            .frame(height: 2000) // large height so both views can pull from it
            .offset(y: offset)
            .clipped()
    }
}
