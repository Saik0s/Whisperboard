import DynamicColor
import SwiftUI
import UIKit

extension Color {
  func adjustedHue(amount: CGFloat) -> Color {
    Color(UIColor(self).adjustedHue(amount: amount))
  }

  func complemented() -> Color {
    adjustedHue(amount: 180.0)
  }

  func lighter(amount: CGFloat = 0.2) -> Color {
    Color(UIColor(self).lighter(amount: amount))
  }

  func darkened(amount: CGFloat = 0.2) -> Color {
    Color(UIColor(self).darkened(amount: amount))
  }

  func saturated(amount: CGFloat = 0.2) -> Color {
    Color(UIColor(self).saturated(amount: amount))
  }

  func desaturated(amount: CGFloat = 0.2) -> Color {
    Color(UIColor(self).desaturated(amount: amount))
  }

  func grayscaled(mode: GrayscalingMode = .lightness) -> Color {
    Color(UIColor(self).grayscaled(mode: mode))
  }

  func inverted() -> Color {
    Color(UIColor(self).inverted())
  }
}
