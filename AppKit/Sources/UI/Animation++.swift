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
}
