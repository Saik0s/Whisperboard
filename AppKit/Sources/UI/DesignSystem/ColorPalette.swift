import DynamicColor
import SwiftUI

// MARK: - Color.DS

extension Color {
  enum DS {}
}

func configureDesignSystem() {
  Color.DS.Background.primary = Color(DynamicColor(hexString: "#1D1820"))
  Color.DS.Background.secondary = Color(DynamicColor(hexString: "#2C2634"))
  Color.DS.Background.tertiary = Color(DynamicColor(hexString: "#4E4857"))
  Color.DS.Background.accent = Color(DynamicColor(hexString: "#d60000"))
  Color.DS.Background.accentAlt = Color(DynamicColor(hexString: "#246BFD"))

  Color.DS.Text.base = Color(DynamicColor(hexString: "#FFFFFF"))
  Color.DS.Text.subdued = Color(DynamicColor(hexString: "#9195A8"))
  Color.DS.Text.accent = Color(DynamicColor(hexString: "#ff0831"))
  Color.DS.Text.accentAlt = Color(DynamicColor(hexString: "#abe4fd"))
}

extension Color.DS {
  enum Background {
    static var primary = Color(hexString: "#1C1C1C")
    static var secondary = Color(hexString: "#2F2F2F")
    static var tertiary = Color(hexString: "#1C1C1C")
    static var accent = Color(hexString: "#FFA500")
    static var accentAlt = Color(hexString: "#87CEEB")
    static var error = Color(hexString: "#FF0000")
    static var success = Color(hexString: "#008000")
    static var warning = Color(hexString: "#FFA500")
    static var link = Color(hexString: "#0000FF")
  }

  enum Text {
    static var base = Color(hexString: "#D3D3D3")
    static var subdued = Color(hexString: "#808080")
    static var accent = Color(hexString: "#FFA500")
    static var accentAlt = Color(hexString: "#87CEEB")
    static var error = Color(hexString: "#FF0000")
    static var success = Color(hexString: "#008000")
    static var warning = Color(hexString: "#FFA500")
    static var link = Color(hexString: "#0000FF")
  }

  enum Stroke {
    static var base = Background.primary.lighten(by: 0.1)
    static var subdued = Background.tertiary.lighten(by: 0.05)
    static var accent = Background.accent.lighten(by: 0.1)
  }

  enum Shadow {
    static var primary = Background.primary.darken(by: 0.2).opacity(0.6)
    static var secondary = Background.primary.darken(by: 0.2).opacity(0.2)
  }
}
