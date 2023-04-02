import Dependencies
import SwiftUI
import XCTestDynamicOverlay

extension DependencyValues {
  var openSettings: @Sendable () async -> Void {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }

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
