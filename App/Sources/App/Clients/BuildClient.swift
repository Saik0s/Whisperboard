import ComposableArchitecture
import Dependencies
import Foundation

// MARK: - BuildClient

struct BuildClient {
  var version: () -> String
  var buildNumber: () -> String
  var githubURL: () -> URL
  var personalWebsiteURL: () -> URL
  var appStoreReviewURL: () -> URL
  var bugReportURL: () -> URL
  var featureRequestURL: () -> URL
}

// MARK: DependencyKey

extension BuildClient: DependencyKey {
  static var liveValue: Self {
    Self(
      version: { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0" },
      buildNumber: { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0" },
      githubURL: { URL(staticString: "https://github.com/Saik0s/Whisperboard") },
      personalWebsiteURL: { URL(staticString: "https://igortarasenko.me") },
      appStoreReviewURL: { URL(staticString: "itms-apps://itunes.apple.com/gb/app/id1661442906?action=write-review&mt=8") },
      bugReportURL: {
        URL(staticString: "https://docs.google.com/forms/d/e/1FAIpQLSfj--VhT4HYZveTXhEHDm5Sd-RNMziDnQkQ1sm70e7ACrrxcg/viewform")
      },
      featureRequestURL: {
        URL(staticString: "https://docs.google.com/forms/d/e/1FAIpQLSd6SW5sMmbaTCkMxp-6AUbWF4CdGu-cFWa8dO0UKKhrMlzrtA/viewform")
      }
    )
  }
}

extension DependencyValues {
  var build: BuildClient {
    get { self[BuildClient.self] }
    set { self[BuildClient.self] = newValue }
  }
}
