import ComposableArchitecture
import SwiftUI

@main
struct WhisperboardApp: App {
  var body: some Scene {
    WindowGroup {
      RootView(
        store: Store(
          initialState: Root.State(),
          reducer: Root()
        )
      )
    }
  }
}
