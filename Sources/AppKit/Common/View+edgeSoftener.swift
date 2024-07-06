import SwiftUI

public extension View {
  func applyVerticalEdgeSofteningMask() -> some View {
    mask {
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: .black, location: 0.02),
          .init(color: .black, location: 0.98),
          .init(color: .clear, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
  }
}
