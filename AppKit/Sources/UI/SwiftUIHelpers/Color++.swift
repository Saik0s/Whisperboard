import DynamicColor
import SwiftUI

extension Color {
  func lighten(by amount: CGFloat = 0.2) -> Color {
    Color(DynamicColor(self).lighter(amount: amount))
  }

  func darken(by amount: CGFloat = 0.2) -> Color {
    Color(DynamicColor(self).darkened(amount: amount))
  }
}

extension Color {
  static let systemBlue: Color = .init(DynamicColor.systemBlue)
  static let systemGreen: Color = .init(DynamicColor.systemGreen)
  static let systemIndigo: Color = .init(DynamicColor.systemIndigo)
  static let systemOrange: Color = .init(DynamicColor.systemOrange)
  static let systemPink: Color = .init(DynamicColor.systemPink)
  static let systemPurple: Color = .init(DynamicColor.systemPurple)
  static let systemRed: Color = .init(DynamicColor.systemRed)
  static let systemTeal: Color = .init(DynamicColor.systemTeal)
  static let systemYellow: Color = .init(DynamicColor.systemYellow)
  static let systemGray: Color = .init(DynamicColor.systemGray)
  #if os(iOS) || os(tvOS) || os(watchOS)
    static let systemGray2: Color = .init(DynamicColor.systemGray2)
    static let systemGray3: Color = .init(DynamicColor.systemGray3)
    static let systemGray4: Color = .init(DynamicColor.systemGray4)
    static let systemGray5: Color = .init(DynamicColor.systemGray5)
    static let systemGray6: Color = .init(DynamicColor.systemGray6)
    static let systemFill: Color = .init(DynamicColor.systemFill)
    static let secondarySystemFill: Color = .init(DynamicColor.secondarySystemFill)
    static let tertiarySystemFill: Color = .init(DynamicColor.tertiarySystemFill)
    static let quaternarySystemFill: Color = .init(DynamicColor.quaternarySystemFill)
    static let systemBackground: Color = .init(DynamicColor.systemBackground)
    static let secondarySystemBackground: Color = .init(DynamicColor.secondarySystemBackground)
    static let tertiarySystemBackground: Color = .init(DynamicColor.tertiarySystemBackground)
    static let systemGroupedBackground: Color = .init(DynamicColor.systemGroupedBackground)
    static let secondarySystemGroupedBackground: Color = .init(DynamicColor.secondarySystemGroupedBackground)
    static let tertiarySystemGroupedBackground: Color = .init(DynamicColor.tertiarySystemGroupedBackground)
  #endif
}
