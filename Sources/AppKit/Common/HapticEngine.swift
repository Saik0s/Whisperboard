import Dependencies
import Foundation
import UIKit

// MARK: - HapticEngine

struct HapticEngine {
  var feedback: @Sendable (UIImpactFeedbackGenerator.FeedbackStyle) async -> Void

  static let live = Self(
    feedback: { style in
      let impact = await UIImpactFeedbackGenerator(style: style)
      await impact.impactOccurred()
    }
  )
}

extension DependencyValues {
  var hapticEngine: HapticEngine {
    get { self[HapticEngine.self] }
    set { self[HapticEngine.self] = newValue }
  }
}

// MARK: - HapticEngine + DependencyKey

extension HapticEngine: DependencyKey {
  static let liveValue = HapticEngine.live
}
