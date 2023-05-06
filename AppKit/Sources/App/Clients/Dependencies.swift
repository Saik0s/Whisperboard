import Dependencies
import SwiftUI
import XCTestDynamicOverlay

/// A property wrapper that provides a closure to open the app's settings.
///
/// The wrapped value is a closure that can be called to open the app's settings page in the system preferences. The
/// closure is obtained from and stored in the `OpenSettingsKey` environment key. The closure is marked as `@Sendable`
/// and `async` to allow concurrency.
///
/// Example usage:
///
/// ```
/// @OpenSettings var openSettings: () async -> Void
///
/// Button("Open Settings") {
/// Task {
/// await openSettings()
/// }
/// }
/// ```
extension DependencyValues {
  /// A property wrapper that provides a closure to open the app's settings.
  ///
  /// - get: Returns the closure stored in the `OpenSettingsKey` environment key.
  /// - set: Sets the closure to the `OpenSettingsKey` environment key.
  /// - note: The closure is marked as `@Sendable` and `async` to allow concurrency.
  var openSettings: @Sendable ()
    async -> Void {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }

  /// A private enumeration that defines a dependency key for opening the app settings.
  ///
  /// The value of this key is a closure that asynchronously opens the app settings URL on the main actor.
  /// The live value of this key uses the `UIApplication.shared.open` method to open the URL.
  /// The test value of this key is an unimplemented stub that can be used with the `@Dependency` property wrapper.
  private enum OpenSettingsKey: DependencyKey {
    typealias Value = @Sendable () async -> Void

    static let liveValue: @Sendable () async -> Void = {
      await MainActor.run {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
      }
    }

    static let testValue: @Sendable () async -> Void = unimplemented(
      #"@Dependency(\.openSettings)"#
    )
  }
}

// extension DependencyValues {
//   var openURL: @Sendable (_ url: URL) async -> Void {
//     get { self[OpenURLKey.self] }
//     set { self[OpenURLKey.self] = newValue }
//   }
//
//   private enum OpenURLKey: DependencyKey {
//     typealias Value = @Sendable (_ url: URL) async -> Void
//
//     static let liveValue: @Sendable (_ url: URL) async -> Void = { url in
//       await MainActor.run {
//         UIApplication.shared.open(url)
//       }
//     }
//
//     static let testValue: @Sendable (_ url: URL) async -> Void = unimplemented(
//       #"@Dependency(\.openURL)"#
//     )
//   }
// }
