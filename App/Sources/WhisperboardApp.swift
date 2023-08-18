import SwiftUI
import WhisperBoardKit

@main
struct WhisperBoardApp: App {
  var body: some Scene {
    WindowGroup {
      AppView()
    }
  }

  init() {
    appSetup()
  }
}
