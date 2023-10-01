import DynamicColor
import SwiftUI

extension RadialGradient {
  static let accent: Self = RadialGradient(
    gradient: Gradient(stops: [
      .init(color: .DS.Background.accent.lighten(by: 0.03), location: 0),
      .init(color: .DS.Background.accent.darken(by: 0.13), location: 0.55),
      .init(color: .DS.Background.accent.darken(by: 0.15), location: 1.0),
    ]),
    center: UnitPoint(x: 0.35, y: 0.35),
    startRadius: 1,
    endRadius: 70
  )

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
