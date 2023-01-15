//
// Gradients.swift
//

import DynamicColor
import SwiftUI

public extension LinearGradient {
  static let cardBackground: Self = .easedGradient(colors: [
    .Palette.primary.lighten(by: 0.1),
    .Palette.primary.darken(by: 0.1),
  ])

  static let cardBorder: Self = .easedGradient(colors: [
    .Palette.primary.lighten(by: 0.3),
    .Palette.primary.lighten(by: 0.1),
  ])

  static let screenBackground: Self = .easedGradient(colors: [
    .Palette.background.lighten(by: 0.3),
    .Palette.background,
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
