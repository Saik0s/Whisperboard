
import Combine
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RootView

struct RootView: View {
  @ObserveInjection var inject

  let store: StoreOf<Root>

  @ObservedObject var viewStore: ViewStore<Root.Tab, Root.Action>

  @Namespace var animation

  init(store: StoreOf<Root>) {
    self.store = store
    viewStore = ViewStore(store) { $0.selectedTab }
  }

  var body: some View {
    TabBarContainerView(
      selectedIndex: viewStore.binding(get: \.rawValue, send: Root.Action.selectTab),
      screen1: RecordingListScreenView(store: store.scope(state: \.recordingListScreen, action: Root.Action.recordingListScreen)),
      screen2: RecordScreenView(store: store.scope(state: \.recordScreen, action: Root.Action.recordScreen)),
      screen3: SettingsScreenView(store: store.scope(state: \.settingsScreen, action: Root.Action.settingsScreen))
    )
    .accentColor(.white)
    .task { viewStore.send(.task) }
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
