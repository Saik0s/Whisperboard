import SwiftUI

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
