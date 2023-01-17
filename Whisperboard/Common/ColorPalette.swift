//
// ColorPalette.swift
//

import DynamicColor
import SwiftUI

// MARK: - Color.Palette

public extension Color {
  enum Palette {
    enum Background {
      public static let primary = Color(DynamicColor(hexString: "#202437"))
      public static let secondary = primary.lighten(by: 0.1)
      public static let tertiary = primary.darken(by: 0.1)
      public static let accent = Color(DynamicColor(hexString: "#fb3d02"))
      public static let accentAlt = Color(DynamicColor(hexString: "#45202f"))
      public static let error = Color(UIColor.systemRed)
      public static let success = Color(UIColor.systemGreen)
      public static let warning = Color(UIColor.systemOrange)
      public static let link = Color(UIColor.systemBlue)
    }
    enum Text {
      public static let base = Color(DynamicColor(hexString: "#FFFFFF"))
      public static let subdued = Color(DynamicColor(hexString: "#afb0b6"))
      public static let accent = Color(DynamicColor(hexString: "#fb3d02"))
      public static let accentAlt = Color(DynamicColor(hexString: "#FFFFFF"))
      public static let error = Color(UIColor.systemRed)
      public static let success = Color(UIColor.systemGreen)
      public static let warning = Color(UIColor.systemOrange)
      public static let link = Color(UIColor.systemBlue)
    }
    typealias Icon = Text
    enum Stroke {
      public static let base = Background.primary.lighten(by: 0.1)
      public static let subdued = Background.tertiary.lighten(by: 0.05)
      public static let accent = Background.accent.lighten(by: 0.1)
    }
    enum Shadow {
      public static let primary = Background.primary.darken(by: 0.2).opacity(0.6)
      public static let secondary = Background.primary.darken(by: 0.2).opacity(0.2)
    }
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
