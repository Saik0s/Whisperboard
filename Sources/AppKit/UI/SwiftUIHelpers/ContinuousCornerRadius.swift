import SwiftUI

extension View {
  func continuousCornerRadius(_ radius: CGFloat) -> some View {
    clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
  }
}
