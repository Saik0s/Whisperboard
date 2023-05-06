import SwiftUI
import WhisperBoardKit

@main
struct WhisperboardApp: App {
  var body: some Scene {
    WindowGroup {
      AppView()
    }
  }

  init() {
    appSetup()
  }
}
