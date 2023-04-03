import Foundation
import Dependencies
import ComposableArchitecture

struct BuildClient {
  var version: () -> String
  var buildNumber: () -> String
  var githubURL: () -> URL
}

extension BuildClient: DependencyKey {
  static var liveValue: Self {
    Self(
      version: { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0" },
      buildNumber: { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0" },
      githubURL: { URL(staticString: "https://github.com/Saik0s/Whisperboard") }
    )
  }
}

extension DependencyValues {
  var build: BuildClient {
    get { self[BuildClient.self] }
    set { self[BuildClient.self] = newValue }
  }
}
