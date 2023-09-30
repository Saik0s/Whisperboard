import SwiftUI

// MARK: - Font.DS

extension Font {
  /// Namespace to prevent naming collisions with static accessors on
  /// SwiftUI's Font.
  ///
  /// Xcode's autocomplete allows for easy discovery of design system fonts.
  /// At any call site that requires a font, type `Font.DesignSystem.<esc>`
  enum DS {}
}

 extension Font.DS {
     static let h1 = Font.custom("Inter-Bold", size: 64)
     static let h2 = Font.custom("Inter-Bold", size: 48)
     static let h3 = Font.custom("Inter-Bold", size: 40)
     static let h4Small = Font.custom("Inter-Bold", size: 32)
     static let h4 = Font.custom("Inter-Bold", size: 28)
     static let h5 = Font.custom("Inter-SemiBold", size: 24)
     static let body1Body1 = Font.custom("Karla-Regular", size: 24)
     static let body1Body1Small = Font.custom("Karla-Regular", size: 22)
     static let h6 = Font.custom("Inter-SemiBold", size: 18)
     static let body2Body2Bold = Font.custom("Karla-Bold", size: 17)
     static let body2Body2 = Font.custom("Karla-Regular", size: 17)
     static let body2Body2Underline = Font.custom("Karla-Regular", size: 17)
     static let base1Semibold = Font.custom("Inter-SemiBold", size: 16)
     static let base1 = Font.custom("Inter-Medium", size: 16)
     static let base2 = Font.custom("Inter-Medium", size: 14)
     static let base2SemiBold = Font.custom("Inter-SemiBold", size: 14)
     static let caption1 = Font.custom("Inter-Medium", size: 12)
     static let caption1Semibold = Font.custom("Inter-SemiBold", size: 12)
     static let caption1Bold = Font.custom("Inter-Bold", size: 12)
     static let caption2 = Font.custom("Inter-Medium", size: 11)
}


extension Font.DS {
  static var titleXL = Font.system(.largeTitle, design: .default).weight(.bold)
  static var titleL = Font.system(.title, design: .default).weight(.bold)
  static var titleM = Font.system(.title2, design: .default).weight(.bold)
  static var titleS = Font.system(.title3, design: .default).weight(.bold)
  static var headlineL = Font.system(.headline, design: .default).weight(.semibold)
  static var headlineM = Font.system(.subheadline, design: .default).weight(.semibold)
  static var headlineS = Font.system(.callout, design: .rounded).weight(.semibold)
  static var bodyL = Font.system(.body, design: .default).weight(.regular)
  static var bodyM = Font.system(.callout, design: .rounded).weight(.regular)
  static var bodyS = Font.system(.caption, design: .rounded).weight(.regular)
  static var footnote = Font.system(.footnote, design: .default).weight(.light)
  static var date = Font.system(.caption, design: .monospaced).weight(.medium)
  static var captionM = Font.system(.caption, design: .rounded).weight(.medium)
  static var captionS = Font.system(.caption2, design: .rounded).weight(.regular)
}

extension Font.DS {
  static var bodyText: Font = .system(size: 17, weight: .light)
  static var subheading: Font = .system(size: 17, weight: .medium)
  static var heading: Font = .system(size: 19, weight: .medium)
  static var largeTitle: Font = .system(.largeTitle, design: .default).weight(.medium).width(.condensed)
}

extension TextStyle {
  static var bodyText = TextStyle(font: .DS.bodyText, lineSpacing: 0, foregroundColor: Color.DS.Text.base, kerning: 0)
  static var subheading = TextStyle(font: .DS.subheading, lineSpacing: 0, foregroundColor: Color.DS.Text.base, kerning: 0)
  static var heading = TextStyle(font: .DS.heading, lineSpacing: 0, foregroundColor: Color.DS.Text.accent, kerning: 0.5)
  static var largeTitle = TextStyle(font: .DS.largeTitle, lineSpacing: 0, foregroundColor: Color.DS.Text.base, kerning: 1)
}
