import DynamicColor
import SwiftUI

// MARK: - Color.DS

extension Color {
  enum DS {
    static let neutral01100 = Color(red: 0.995, green: 0.995, blue: 0.995, opacity: 1)
    static let neutral0195 = Color(red: 0.995, green: 0.995, blue: 0.995, opacity: 0.949)
    static let neutral0120 = Color(red: 0.995, green: 0.995, blue: 0.995, opacity: 0.200)
    static let neutral0110 = Color(red: 0.995, green: 0.995, blue: 0.995, opacity: 0.100)
    static let neutral02100 = Color(red: 0.954, green: 0.961, blue: 0.966, opacity: 1)
    static let neutral0250 = Color(red: 0.954, green: 0.961, blue: 0.966, opacity: 0.5)
    static let neutral03100 = Color(red: 0.910, green: 0.926, blue: 0.937, opacity: 1)
    static let neutral0375 = Color(red: 0.909, green: 0.925, blue: 0.937, opacity: 0.75)
    static let neutral0350 = Color(red: 0.910, green: 0.926, blue: 0.937, opacity: 0.5)
    static let neutral04100 = Color(red: 0.423, green: 0.446, blue: 0.458, opacity: 1)
    static let neutral0475 = Color(red: 0.423, green: 0.446, blue: 0.458, opacity: 0.75)
    static let neutral0450 = Color(red: 0.423, green: 0.446, blue: 0.458, opacity: 0.5)
    static let neutral0425 = Color(red: 0.423, green: 0.446, blue: 0.458, opacity: 0.25)
    static let neutral0415 = Color(red: 0.423, green: 0.446, blue: 0.458, opacity: 0.150)
    static let neutral05100 = Color(red: 0.205, green: 0.220, blue: 0.225, opacity: 1)
    static let neutral0550 = Color(red: 0.205, green: 0.220, blue: 0.225, opacity: 0.5)
    static let neutral06100 = Color(red: 0.137, green: 0.149, blue: 0.152, opacity: 1)
    static let neutral0695 = Color(red: 0.137, green: 0.149, blue: 0.152, opacity: 0.949)
    static let neutral0690 = Color(red: 0.137, green: 0.149, blue: 0.152, opacity: 0.899)
    static let neutral0650 = Color(red: 0.137, green: 0.149, blue: 0.152, opacity: 0.5)
    static let neutral07100 = Color(red: 0.078, green: 0.090, blue: 0.094, opacity: 1)
    static let neutral0795 = Color(red: 0.078, green: 0.090, blue: 0.094, opacity: 0.949)
    static let neutral0750 = Color(red: 0.078, green: 0.090, blue: 0.094, opacity: 0.5)
    static let primary02 = Color(red: 0.555, green: 0.334, blue: 0.916, opacity: 1)
    static let primary015 = Color(red: 0, green: 0.517, blue: 1, opacity: 0.050)
    static let primary0110 = Color(red: 0, green: 0.517, blue: 1, opacity: 0.100)
    static let primary0150 = Color(red: 0, green: 0.517, blue: 1, opacity: 0.5)
    static let primary01100 = Color(red: 0.854, green: 0.223, blue: 0.007, opacity: 1)
    static let accents05 = Color(red: 0.866, green: 0.655, blue: 0.245, opacity: 1)
    static let accents04 = Color(red: 0.549, green: 0.396, blue: 0.515, opacity: 1)
    static let accents02 = Color(red: 0.244, green: 0.565, blue: 0.941, opacity: 1)
    static let accents01 = Color(red: 0, green: 0.517, blue: 1, opacity: 1)
    static let accents03 = Color(red: 0.247, green: 0.866, blue: 0.470, opacity: 1)
    static let code01 = Color(red: 0.272, green: 0.868, blue: 0.999, opacity: 1)
    static let code02 = Color(red: 0.699, green: 0.908, blue: 0.601, opacity: 1)
    static let code03 = Color(red: 0.982, green: 0.410, blue: 0.165, opacity: 1)
    static let code04 = Color(red: 1, green: 0.593, blue: 0.910, opacity: 1)

    enum Background {
      static var primary = Color.DS.neutral07100
      static var secondary = Color.DS.neutral06100
      static var tertiary = Color.DS.neutral0550
      static var accent = Color.DS.primary01100
      static var accentAlt = Color.DS.primary02
      static var error = Color.DS.primary01100
      static var success = Color.DS.accents03
      static var warning = Color.DS.accents05
    }

    enum Text {
      static var base = Color.DS.neutral01100
      static var subdued = Color.DS.neutral04100
      static var accent = Color.DS.primary01100
      static var accentAlt = Color.DS.primary02
      static var error = Color.DS.primary01100
      static var success = Color.DS.accents03
      static var warning = Color.DS.accents05
      static var link = Color.DS.accents01
      static var overAccent = Color.DS.neutral01100
    }

    enum Stroke {
      static var base = Color.DS.neutral04100
      static var subdued = Color.DS.neutral04100
      static var accent = Color.DS.primary01100
    }

    enum Shadow {
      static var primary = Color.DS.neutral07100
      static var secondary = Color.DS.neutral06100
      static var accent = Color.DS.primary01100
    }
  }
}
