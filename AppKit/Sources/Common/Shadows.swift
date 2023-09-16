import SwiftUI

// MARK: - ShadowStyle

enum ShadowStyle {
  case card
  case button
}

extension View {
  func shadow(style: ShadowStyle) -> some View {
    switch style {
    case .card:
      return shadow(color: Color.DS.Shadow.primary.darken().opacity(0.25), radius: 12, x: 0, y: 8)
    case .button:
      return shadow(color: Color.DS.Shadow.primary.darken().opacity(0.5), radius: 16, x: 0, y: 8)
    }
  }
}
