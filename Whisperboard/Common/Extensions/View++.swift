import SwiftUI

public extension View {
  func erase() -> AnyView {
    AnyView(self)
  }

  @ViewBuilder
  func applyIf(_ condition: @autoclosure () -> Bool, apply: (Self) -> some View) -> some View {
    if condition() {
      apply(self)
    } else {
      self
    }
  }

  @ViewBuilder
  func hidden(_ hides: Bool) -> some View {
    switch hides {
    case true: hidden()
    case false: self
    }
  }
}
