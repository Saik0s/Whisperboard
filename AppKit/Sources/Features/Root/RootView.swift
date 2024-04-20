import Combine
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RootView

struct RootView: View {
  @ObserveInjection var inject

  @Perception.Bindable var store: StoreOf<Root>

  @Namespace var animation

  var body: some View {
    WithPerceptionTracking {
      TabBarContainerView(
        selectedIndex: $store.selectedTab.rawValue.sending(\.selectTab),
        screen1: RecordingListScreenView(store: store.scope(state: \.recordingListScreen, action: \.recordingListScreen)),
        screen2: RecordScreenView(store: store.scope(state: \.recordScreen, action: \.recordScreen)),
        screen3: SettingsScreenView(store: store.scope(state: \.settingsScreen, action: \.settingsScreen))
      )
      .accentColor(.white)
      .task { store.send(.task) }
    }
    .enableInjection()
  }
}

// MARK: - Root_Previews

struct Root_Previews: PreviewProvider {
  struct ContentView: View {
    var body: some View {
      RootView(
        store: Store(
          initialState: Root.State(),
          reducer: { Root() }
        )
      )
    }
  }

  static var previews: some View {
    ContentView()
  }
}
