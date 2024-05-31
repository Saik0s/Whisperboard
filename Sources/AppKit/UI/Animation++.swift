import SwiftUI

extension Animation {
  static func gentleBounce() -> Animation {
    .interpolatingSpring(
      mass: 1,
      stiffness: 170,
      damping: 15,
      initialVelocity: 0
    )
  }

  static func showHide() -> Animation {
    .interpolatingSpring(
      mass: 1,
      stiffness: 300,
      damping: 25,
      initialVelocity: -5
    )
  }

  static func hardShowHide() -> Animation {
    .interpolatingSpring(
      mass: 1,
      stiffness: 200,
      damping: 30,
      initialVelocity: 0
    )
  }
}
