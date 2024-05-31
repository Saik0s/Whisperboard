import ComposableArchitecture
import Dependencies
import Foundation
import UIKit

extension DependencyValues {
  var didBecomeActive: @Sendable () async -> AsyncStream<Void> {
    get { self[DidBecomeActiveKey.self] }
    set { self[DidBecomeActiveKey.self] = newValue }
  }

  var willEnterForeground: @Sendable () async -> AsyncStream<Void> {
    get { self[WillEnterForegroundKey.self] }
    set { self[WillEnterForegroundKey.self] = newValue }
  }

  var didEnterBackground: @Sendable () async -> AsyncStream<Void> {
    get { self[DidEnterBackgroundKey.self] }
    set { self[DidEnterBackgroundKey.self] = newValue }
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

// MARK: - WillEnterForegroundKey

private enum WillEnterForegroundKey: DependencyKey {
  static let liveValue: @Sendable () async -> AsyncStream<Void> = {
    await AsyncStream(
      NotificationCenter.default
        .notifications(named: UIApplication.willEnterForegroundNotification)
        .map { _ in }
    )
  }
}

// MARK: - DidEnterBackgroundKey

private enum DidEnterBackgroundKey: DependencyKey {
  static let liveValue: @Sendable () async -> AsyncStream<Void> = {
    await AsyncStream(
      NotificationCenter.default
        .notifications(named: UIApplication.didEnterBackgroundNotification)
        .map { _ in }
    )
  }
}
