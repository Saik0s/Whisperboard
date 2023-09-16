import Foundation
import SwiftUI
import SwiftUIIntrospect
import UIKit

extension View {
  func removeNavigationBackground() -> some View {
    introspect(.navigationStack, on: .iOS(.v16, .v17), scope: .ancestor) { navigation in
      func removeBackground(_ view: UIView) {
        let viewType = String(describing: type(of: view))
        let obfuscatedUIHostingView = "`VJIptujohWjfx"
        let deobfuscatedUIHostingView = deobfuscate(obfuscatedUIHostingView, shift: 1)
        if viewType.starts(with: deobfuscatedUIHostingView) {
          view.backgroundColor = .clear
        }
        view.subviews.forEach(removeBackground)
      }

      func deobfuscate(_ text: String, shift: Int) -> String {
        String(text.unicodeScalars.map { char in
          if let scalar = UnicodeScalar((char.value - UInt32(shift)) % 128) {
            return Character(scalar)
          } else {
            return Character(char)
          }
        })
      }

      removeBackground(navigation.view)
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

extension View {
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
