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
      ZStack {
        Color.DS.Background.primary

        spotlight()
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .offset(x: -120, y: -90)

        spotlight()
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          .offset(x: 90, y: 90)
      }
      .ignoresSafeArea()
    }
  }

  private func spotlight() -> some View {
    RadialGradient.purpleSpotlight
      .opacity(0.25)
      .blendMode(.overlay)
      .frame(width: 375, height: 375)
      .blur(radius: 80)
  }
}
