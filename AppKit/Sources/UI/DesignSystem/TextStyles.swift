import SwiftUI

extension TextStyle {
  static let body = TextStyle(font: Font.DS.body, lineSpacing: 4, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let bodyBold = TextStyle(font: Font.DS.bodyBold, lineSpacing: 4, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let caption = TextStyle(font: Font.DS.caption, lineSpacing: 2, foregroundColor: Color.DS.Text.subdued, kerning: 0)
  static let captionBase = TextStyle(font: Font.DS.footnote, lineSpacing: 2, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let footnote = TextStyle(font: Font.DS.footnote, lineSpacing: 1, foregroundColor: Color.DS.Text.subdued, kerning: 0)
  static let smallIcon = TextStyle(font: Font.DS.footnote, lineSpacing: 4, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let headline = TextStyle(font: Font.DS.title, lineSpacing: 7, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let label = TextStyle(font: Font.DS.body, lineSpacing: 5, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let sublabel = TextStyle(font: Font.DS.body, lineSpacing: 3, foregroundColor: Color.DS.Text.subdued, kerning: 0)
  static let navigationBarButton = TextStyle(font: Font.DS.actionSecondary, lineSpacing: 6, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let navigationTitle = TextStyle(font: Font.DS.title, lineSpacing: 11, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let primaryButton = TextStyle(font: Font.DS.action, lineSpacing: 7, foregroundColor: Color.DS.Text.overAccent, kerning: 0)
  static let secondaryButton = TextStyle(font: Font.DS.actionSecondary, lineSpacing: 6, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let subheadline = TextStyle(font: Font.DS.titleSmall, lineSpacing: 7, foregroundColor: Color.DS.Text.subdued, kerning: 0)
}

// MARK: - TextStyle

struct TextStyle {
  let font: Font
  let lineSpacing: CGFloat
  let foregroundColor: Color
  let kerning: CGFloat

  init(font: Font, lineSpacing: CGFloat, foregroundColor: Color, kerning: CGFloat) {
    self.font = font
    self.lineSpacing = lineSpacing
    self.foregroundColor = foregroundColor
    self.kerning = kerning
  }

  func apply(to text: some View) -> some View {
    text
      .font(font)
      .lineSpacing(lineSpacing)
      .foregroundColor(foregroundColor)
      .kerning(kerning)
  }
}

extension View {
  func textStyle(_ style: TextStyle) -> some View {
    style.apply(to: self)
  }
}
