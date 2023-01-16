//
// Gradients.swift
//

import DynamicColor
import SwiftUI

public extension LinearGradient {
  static let cardBackground: Self = .easedGradient(colors: [
    .Palette.Background.tertiary.lighten(by: 0.1),
    .Palette.Background.tertiary.darken(by: 0.1),
  ])

  static let cardBorder: Self = .easedGradient(colors: [
    .Palette.Background.tertiary.lighten(by: 0.3),
    .Palette.Background.tertiary.lighten(by: 0.1),
  ])

  static let screenBackground: Self = .easedGradient(colors: [
    .Palette.Background.primary.lighten(by: 0.3),
    .Palette.Background.primary,
  ])
}

public extension LinearGradient {
  static func easedGradient(
    colors: [Color],
    steps: UInt = 8,
    startPoint: UnitPoint = UnitPoint(x: 0.5, y: 0),
    endPoint: UnitPoint = UnitPoint(x: 0.5, y: 0.930)
  ) -> Self {
    let palette = colors
      .map { UIColor($0) }
      .gradient
      .colorPalette(amount: steps, inColorSpace: .lab)

    return LinearGradient(
      colors: palette.map { Color($0) },
      startPoint: startPoint,
      endPoint: endPoint
    )
  }
}
