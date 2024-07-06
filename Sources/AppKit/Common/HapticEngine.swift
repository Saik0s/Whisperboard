import Foundation
import UIKit

struct HapticEngine {
  var feedback: @Sendable (UIImpactFeedbackGenerator.FeedbackStyle) async -> Void

  static let live = Self(
    feedback: { style in
      let impact = UIImpactFeedbackGenerator(style: style)
      impact.impactOccurred()
    }
  )
}

extension DependencyValues {
  var hapticEngine: HapticEngine {
    get { self[HapticEngine.self] }
    set { self[HapticEngine.self] = newValue }
  }
}

extension HapticEngine: DependencyKey {
  static let liveValue = HapticEngine.live
}
