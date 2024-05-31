import SwiftUI

public extension View {
  func scrollAnchor(id: some Hashable, valueToTrack: some Equatable, anchor: UnitPoint = .bottom) -> some View {
    if #available(iOS 17.0, *) {
      return defaultScrollAnchor(anchor)
    }

    return ScrollViewReader { scrollView in
      onChange(of: valueToTrack) {
        withAnimation {
          scrollView.scrollTo(id, anchor: anchor)
        }
      }
    }
  }
}
