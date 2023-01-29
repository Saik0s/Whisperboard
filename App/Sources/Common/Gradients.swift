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
