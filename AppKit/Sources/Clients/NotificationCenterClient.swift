import ComposableArchitecture
import Dependencies
import Foundation
import UIKit

extension DependencyValues {
  var didBecomeActive: @Sendable () async -> AsyncStream<Void> {
    get { self[DidBecomeActiveKey.self] }
    set { self[DidBecomeActiveKey.self] = newValue }
  }
}

// MARK: - DidBecomeActiveKey

private enum DidBecomeActiveKey: DependencyKey {
  static let liveValue: @Sendable () async -> AsyncStream<Void> = {
    await AsyncStream(
      NotificationCenter.default
        .notifications(named: UIApplication.didBecomeActiveNotification)
        .map { _ in }
    )
  }
}
