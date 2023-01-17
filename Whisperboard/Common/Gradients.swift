//
// Gradients.swift
//

import DynamicColor
import SwiftUI

public extension LinearGradient {
  static let cardPrimaryBackground: Self = .easedGradient(colors: [
    .Palette.Background.secondary.lighten(by: 0.1),
    .Palette.Background.secondary,
  ], startPoint: .topLeading, endPoint: .bottomTrailing)

  static let cardPrimaryBorder: Self = .easedGradient(colors: [
    .Palette.Stroke.subdued.lighten(by: 0.1),
    .Palette.Stroke.subdued,
  ], startPoint: .topLeading, endPoint: .bottomTrailing)

  static let cardSecondaryBackground: Self = .easedGradient(colors: [
    .Palette.Background.tertiary.lighten(by: 0.05),
    .Palette.Background.tertiary,
  ], startPoint: .topLeading, endPoint: .bottomTrailing)

  static let cardSecondaryBorder: Self = .easedGradient(colors: [
    .Palette.Stroke.subdued.lighten(by: 0.05),
    .Palette.Stroke.subdued,
  ], startPoint: .topLeading, endPoint: .bottomTrailing)

  static let screenBackground: Self = .easedGradient(colors: [
    .Palette.Background.primary.lighten(by: 0.05),
    .Palette.Background.primary,
    .Palette.Background.primary,
  ])
}

public extension LinearGradient {
  static func easedGradient(
    colors: [Color],
    steps: UInt = 8,
    startPoint: UnitPoint = UnitPoint(x: 0.5, y: 0),
    endPoint: UnitPoint = UnitPoint(x: 0.5, y: 1)
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
