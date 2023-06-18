import Foundation
import SwiftUI
import SwiftUIIntrospect

extension View {
  func removeNavigationBackground() -> some View {
    introspect(.navigationStack, on: .iOS(.v16, .v17), scope: .ancestor) { navigation in
      navigation.view.subviews.first?.subviews.first?.subviews.first?.backgroundColor = .clear
    }
  }

  func removeClipToBounds() -> some View {
    introspect(.scrollView, on: .iOS(.v15, .v16, .v17), scope: .ancestor) { scrollView in
      scrollView.clipsToBounds = false

      var current: UIView = scrollView
      while let superview = current.superview {
        if superview is UIWindow == false, superview.clipsToBounds {
          superview.clipsToBounds = false
        }
        current = superview
      }
    }
  }
}
