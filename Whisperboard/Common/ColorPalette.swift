//
// ColorPalette.swift
//

import DynamicColor
import SwiftUI

// MARK: - Color.Palette

public extension Color {
  enum Palette {
    public static let primary = Color(DynamicColor(hexString: "#231942"))
    public static let secondary = Color(DynamicColor(hexString: "#fb3d02"))
    public static let accent = primary.lighten(by: 0.4)
    public static let background = primary.darken(by: 0.1)
    public static let text = primary.lighten(by: 0.8)
    public static let error = Color(UIColor.systemRed)
    public static let success = Color(UIColor.systemGreen)
    public static let warning = Color(UIColor.systemOrange)
    public static let link = Color(UIColor.systemBlue)
    public static let disabled = primary.darken(by: 0.6)
    public static let placeholder = primary.lighten(by: 0.6)
    public static let separator = primary.lighten(by: 0.8)
    public static let shadow = primary.darken(by: 0.4).opacity(0.5)
    public static let transparent = Color.clear
  }
}

public extension Color {
  func lighten(by amount: CGFloat = 0.2) -> Color {
    Color(UIColor(self).lighter(amount: amount))
  }

  func darken(by amount: CGFloat = 0.2) -> Color {
    Color(UIColor(self).darkened(amount: amount))
  }
}
