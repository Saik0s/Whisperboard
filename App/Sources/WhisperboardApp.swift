import SwiftUI
import WhisperBoardKit
import XCTestDynamicOverlay

@main
struct WhisperBoardApp: App {
  var body: some Scene {
    WindowGroup {
      if ProcessInfo.processInfo.environment["UITesting"] == "true" {
        TestingAppView()
      } else if _XCTIsTesting {
        EmptyView()
      } else {
        AppView()
      }
    }
  }
}
