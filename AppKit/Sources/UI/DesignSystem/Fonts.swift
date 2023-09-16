import SwiftUI

// MARK: - Font.DS

extension Font {
  enum DS {}
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
  static var bodyText: Font = .system(size: 17)
  static var subheading: Font = .system(size: 15)
  static var heading: Font = .system(size: 20, weight: .bold)
  static var largeTitle: Font = .system(size: 34, weight: .bold)
}

extension TextStyle {
  static var bodyText = TextStyle(font: .DS.bodyText, lineSpacing: 20.4, foregroundColor: Color.DS.Text.base, kerning: 0)
  static var subheading = TextStyle(font: .DS.subheading, lineSpacing: 18, foregroundColor: Color.DS.Text.subdued, kerning: 0)
  static var heading = TextStyle(font: .DS.heading, lineSpacing: 24, foregroundColor: Color.DS.Text.accent, kerning: 0.5)
  static var largeTitle = TextStyle(font: .DS.largeTitle, lineSpacing: 40.8, foregroundColor: Color.DS.Text.accentAlt, kerning: 1)
}
