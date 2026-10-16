//
//  OnboardingStageView.swift
//  Ovra
//
//  First-launch intro: the screen dims, the Ovra orb appears with a glow in
//  the theme's colors, then the orb morphs into the onboarding window.
//
//  Rendering notes (why it looks the same on every Mac):
//  • The backdrop is forced dark, so it doesn't change with Light/Dark mode.
//  • The logo's cut is real geometry (OrbMorphShape), not a blend-mode mask.
//  • The glow is flattened with drawingGroup() and uses normal blending, so it
//    never blows out to white over a bright desktop.
//  • The window shadow is its own blurred shape, so text and glow never get
//    shadows of their own.
//

import SwiftUI

/// Borderless full-screen window that can still take keyboard focus.
final class OnboardingStageWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

struct OnboardingStageView: View {
  /// The stage is pinned to the screen size so animating children (the glow
  /// grows past the screen during the morph) can never resize the window.
  let screenSize: CGSize
  let cardSize: CGSize
  let onComplete: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var theme: Theme = .bluePurple
  @State private var showBackdrop = false
  @State private var showOrb = false
  @State private var showWordmark = false
  @State private var showHint = false
  @State private var isExpanded = false
  @State private var showContent = false
  @State private var isLeaving = false
  @State private var hasStartedMorph = false

  private let orbSize: CGFloat = 132

  private var shapeSize: CGSize {
    isExpanded ? cardSize : CGSize(width: orbSize, height: orbSize)
  }

  private var morphShape: OrbMorphShape {
    OrbMorphShape(cornerRadius: isExpanded ? 26 : orbSize / 2, cut: isExpanded ? 0 : 0.075)
  }

  var body: some View {
    ZStack {
      // Dimmed, blurred desktop tinted with the theme's darkest color.
      ZStack {
        StageBlur()
        Color.black.opacity(0.55)
        (theme.colorHexes.last.map { Color(hex: $0) } ?? .black).opacity(0.3)
        RadialGradient(
          colors: [ (theme.colorHexes.first.map { Color(hex: $0) } ?? .clear).opacity(0.35), .clear ],
          center: .center, startRadius: 40, endRadius: 760
        )
      }
      .animation(.easeInOut(duration: 0.6), value: theme)
      .opacity(showBackdrop ? 1 : 0)
      .ignoresSafeArea()

      // Glow behind the orb / window.
      StageGlow(theme: theme, size: shapeSize, canvas: screenSize, isExpanded: isExpanded, reduceMotion: reduceMotion)
        .opacity(showOrb && !isLeaving ? 1 : 0)

      // The orb that becomes the window.
      ZStack {
        // Shadow as its own shape (no .shadow on the group).
        morphShape
          .fill(Color.black.opacity(isExpanded ? 0.55 : 0))
          .blur(radius: 40)
          .offset(y: 22)

        morphShape
          .fill(Color(white: 0.05))

        morphShape
          .fill(theme.gradient)
          .opacity(isExpanded ? 1 : 0)

        if showContent {
          OnboardingView(onFinish: leave, chosenTheme: $theme)
            .frame(width: cardSize.width, height: cardSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }

        morphShape
          .stroke(Color.white.opacity(isExpanded ? 0.16 : 0.1), lineWidth: 0.5)
      }
      .frame(width: shapeSize.width, height: shapeSize.height)
      .scaleEffect(showOrb ? (isLeaving ? 0.92 : 1) : 0.3)
      .opacity(showOrb && !isLeaving ? 1 : 0)
      .accessibilityHidden(!showContent)

      // Wordmark under the orb.
      VStack(spacing: 10) {
        Text("Ovra")
          .font(.system(size: 44, weight: .bold))
          .tracking(-1)
        Text(NSLocalizedString("The browser that's yours.", comment: ""))
          .font(.system(size: 16))
          .opacity(0.75)
        Text(NSLocalizedString("Click anywhere or press Return", comment: ""))
          .font(.system(size: 12, weight: .medium))
          .opacity(showHint ? 0.5 : 0)
          .padding(.top, 18)
      }
      .foregroundColor(.white)
      .offset(y: orbSize / 2 + 100)
      .opacity(showWordmark && !hasStartedMorph ? 1 : 0)
      .offset(y: showWordmark ? 0 : 12)
      .allowsHitTesting(false)

      // Return starts the morph during the intro.
      if !hasStartedMorph {
        Button("", action: morph)
          .keyboardShortcut(.defaultAction)
          .opacity(0)
          .frame(width: 0, height: 0)
          .accessibilityHidden(true)
      }
    }
    .frame(width: screenSize.width, height: screenSize.height)
    .clipped()
    .contentShape(Rectangle())
    .onTapGesture { if !hasStartedMorph { morph() } }
    .task { await runIntro() }
  }

  // MARK: - Sequence

  private func pause(_ seconds: Double) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
  }

  private func runIntro() async {
    if reduceMotion {
      withAnimation(.easeInOut(duration: 0.4)) { showBackdrop = true; showOrb = true; showWordmark = true }
      await pause(1.2)
      morph()
      return
    }
    await pause(0.15)
    withAnimation(.easeOut(duration: 0.7)) { showBackdrop = true }
    await pause(0.35)
    withAnimation(.spring(response: 0.75, dampingFraction: 0.62)) { showOrb = true }
    await pause(0.7)
    withAnimation(.easeOut(duration: 0.7)) { showWordmark = true }
    await pause(1.1)
    withAnimation(.easeInOut(duration: 0.6)) { showHint = true }
    await pause(1.8)
    morph()
  }

  private func morph() {
    guard !hasStartedMorph else { return }
    hasStartedMorph = true
    if reduceMotion {
      withAnimation(.easeInOut(duration: 0.35)) {
        isExpanded = true
        showContent = true
      }
      return
    }
    withAnimation(.easeOut(duration: 0.25)) { showWordmark = false }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) { isExpanded = true }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
      withAnimation(.easeOut(duration: 0.45)) { showContent = true }
    }
  }

  private func leave() {
    withAnimation(.easeIn(duration: reduceMotion ? 0.2 : 0.35)) { isLeaving = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      withAnimation(.easeOut(duration: 0.4)) { showBackdrop = false }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
      onComplete()
    }
  }
}

// MARK: - Shape

/// A rounded rectangle with the Ovra diagonal cut. As a circle with the cut it
/// is the logo; animating the corner radius and cut to 0 turns it into the
/// onboarding window, so the morph is one continuous shape.
struct OrbMorphShape: Shape {
  var cornerRadius: CGFloat
  /// Cut width as a fraction of the shorter side (0 = no cut).
  var cut: CGFloat

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(cornerRadius, cut) }
    set { cornerRadius = newValue.first; cut = newValue.second }
  }

  func path(in rect: CGRect) -> Path {
    let side = min(rect.width, rect.height)
    let base = Path(roundedRect: rect, cornerRadius: min(cornerRadius, side / 2), style: .continuous)
    guard cut > 0.001 else { return base }

    // A "/" band through a point a little below-right of centre, like the logo.
    let center = CGPoint(x: rect.midX + side * 0.06, y: rect.midY + side * 0.06)
    let along = CGVector(dx: 0.70710678, dy: -0.70710678)
    let across = CGVector(dx: 0.70710678, dy: 0.70710678)
    let length = max(rect.width, rect.height) * 2
    let half = side * cut / 2
    func point(_ a: CGFloat, _ b: CGFloat) -> CGPoint {
      CGPoint(x: center.x + along.dx * a + across.dx * b, y: center.y + along.dy * a + across.dy * b)
    }
    var band = Path()
    band.move(to: point(-length, -half))
    band.addLine(to: point(length, -half))
    band.addLine(to: point(length, half))
    band.addLine(to: point(-length, half))
    band.closeSubpath()
    return base.subtracting(band)
  }
}

// MARK: - Glow

private struct StageGlow: View {
  let theme: Theme
  let size: CGSize
  /// Fixed drawing area (the screen), so the glow never affects layout and
  /// drawingGroup() has room for the blur.
  let canvas: CGSize
  let isExpanded: Bool
  let reduceMotion: Bool

  var body: some View {
    let colors = theme.colorHexes.map { Color(hex: $0) }
    let ring = colors + [colors.first ?? .white]
    let light = theme.colorHexes.first.map(Self.lightTint) ?? .white

    TimelineView(.animation(paused: reduceMotion)) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      let pulse = reduceMotion ? 1 : 1 + 0.05 * sin(t * 1.8)
      ZStack {
        // Outer bloom.
        RoundedRectangle(cornerRadius: isExpanded ? 70 : size.width * 2, style: .continuous)
          .fill(AngularGradient(colors: ring, center: .center))
          .rotationEffect(.degrees(reduceMotion ? 0 : t * 40))
          .frame(width: size.width * (isExpanded ? 1.12 : 2.6), height: size.height * (isExpanded ? 1.16 : 2.6))
          .blur(radius: isExpanded ? 70 : 50)
          .opacity(isExpanded ? 0.9 : 0.95)
          .scaleEffect(pulse)

        // Inner ring, turning the other way.
        RoundedRectangle(cornerRadius: isExpanded ? 60 : size.width * 2, style: .continuous)
          .fill(AngularGradient(colors: ring.reversed(), center: .center))
          .rotationEffect(.degrees(reduceMotion ? 0 : -t * 28))
          .frame(width: size.width * (isExpanded ? 1.0 : 1.7), height: size.height * (isExpanded ? 1.0 : 1.7))
          .blur(radius: isExpanded ? 45 : 26)
          .opacity(isExpanded ? 0.45 : 0.9)

        // Soft light in the theme's color that shows through the logo's cut.
        if !isExpanded {
          Circle()
            .fill(RadialGradient(colors: [light, light.opacity(0.6), .clear],
                                 center: .center, startRadius: 0, endRadius: size.width * 0.65))
            .frame(width: size.width * 1.3, height: size.height * 1.3)
            .blur(radius: 10)
            .scaleEffect(pulse)
        }
      }
      .frame(width: canvas.width, height: canvas.height)
      .drawingGroup()
    }
    .animation(.spring(response: 0.9, dampingFraction: 0.82), value: isExpanded)
    .animation(.easeInOut(duration: 0.6), value: theme)
    .frame(width: canvas.width, height: canvas.height)
    .allowsHitTesting(false)
  }

  /// The theme color lifted toward white — bright, but still clearly colored.
  private static func lightTint(_ hex: String) -> Color {
    let base = NSColor(Color(hex: hex)).usingColorSpace(.sRGB) ?? .white
    return Color(nsColor: base.blended(withFraction: 0.45, of: .white) ?? base)
  }
}

/// Dark blur of whatever is behind the window, regardless of Light/Dark mode.
private struct StageBlur: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    view.appearance = NSAppearance(named: .darkAqua)
    return view
  }
  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
