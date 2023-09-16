import SwiftUI

extension View {
  func addBorder(_ content: some ShapeStyle, width: CGFloat = 1, cornerRadius: CGFloat) -> some View {
    let roundedRect = RoundedRectangle(cornerRadius: cornerRadius)
    return clipShape(roundedRect)
      .overlay(roundedRect.strokeBorder(content, lineWidth: width))
  }
}
