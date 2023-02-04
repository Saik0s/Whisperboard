import AppDevUtils
import DynamicColor
import SwiftUI

public extension LinearGradient {
  static let cardPrimaryBackground: Self = .easedGradient(colors: [
    .DS.Background.secondary.lighten(by: 0.1),
    .DS.Background.secondary,
  ], startPoint: .topLeading, endPoint: .bottomTrailing)

  static let cardPrimaryBorder: Self = .easedGradient(colors: [
    .DS.Stroke.subdued.lighten(by: 0.1),
    .DS.Stroke.subdued,
  ], startPoint: .topLeading, endPoint: .bottomTrailing)

  static let cardSecondaryBackground: Self = .easedGradient(colors: [
    .DS.Background.tertiary.lighten(by: 0.05),
    .DS.Background.tertiary,
  ], startPoint: .topLeading, endPoint: .bottomTrailing)

  static let cardSecondaryBorder: Self = .easedGradient(colors: [
    .DS.Stroke.subdued.lighten(by: 0.05),
    .DS.Stroke.subdued,
  ], startPoint: .topLeading, endPoint: .bottomTrailing)

  static let screenBackground: Self = .easedGradient(colors: [
    .DS.Background.primary.lighten(by: 0.05),
    .DS.Background.primary,
    .DS.Background.primary,
  ])
}

public extension RadialGradient {
  static let purpleSpotlight: Self = RadialGradient(
    gradient: Gradient(stops: [
      .init(color: Color(hexString: "#F099F2"), location: 0),
      .init(color: Color(hexString: "#726BCE"), location: 0.55),
      .init(color: Color(hexString: "#8350D7"), location: 1.0),
    ]),
    center: UnitPoint(x: 0.62, y: 0.39),
    startRadius: 1,
    endRadius: 120
  )
}

public extension View {
  @ViewBuilder
  func screenRadialBackground() -> some View {
    background {
      ScreenRadialBackgroundView()
    }
  }
}

// MARK: - ScreenRadialBackgroundView

struct ScreenRadialBackgroundView: View {
  @State var topSpotlightOffset: CGSize = .zero
  @State var bottomSpotlightOffset: CGSize = .zero

  let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

  var body: some View {
    ZStack {
      Color.DS.Background.primary

      spotlight()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .offset(x: -120, y: -90)
        .offset(topSpotlightOffset)

      spotlight()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .offset(x: 90, y: 90)
        .offset(bottomSpotlightOffset)
    }
    .ignoresSafeArea()
    .onReceive(timer) { _ in
      animateSpotlights()
    }
    .task {
      animateSpotlights()
    }
  }

  private func animateSpotlights() {
    withAnimation(.interpolatingSpring(stiffness: 170, damping: 15).speed(0.03)) {
      let screenSize = UIScreen.main.bounds.size

      let horizontal: CGFloat = .random(in: -50 ... screenSize.width)
      let vertical: CGFloat = .random(in: -50 ... (screenSize.height / 4))
      topSpotlightOffset = CGSize(width: horizontal, height: vertical)

      let horizontal1: CGFloat = .random(in: -screenSize.width ... 50)
      let vertical1: CGFloat = .random(in: -(screenSize.height / 4) ... 50)
      bottomSpotlightOffset = CGSize(width: horizontal1, height: vertical1)
    }
  }

  private func spotlight() -> some View {
    let size = UIScreen.main.bounds.size
    return Circle()
      .fill(RadialGradient.purpleSpotlight)
      .frame(width: size.width, height: size.width)
      .blur(radius: 90)
      .compositingGroup()
      .blendMode(.overlay)
  }
}
