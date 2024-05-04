import Combine
import ComposableArchitecture
import Inject
import NavigationTransitions
import SwiftUI

// MARK: - RootView

struct RootView: View {
  @ObserveInjection var inject

  @Perception.Bindable var store: StoreOf<Root>

  var body: some View {
    WithPerceptionTracking {
      TabBarContainerView(
        selectedIndex: $store.selectedTab.rawValue.sending(\.selectTab),
        screen1: NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
          RecordingListScreenView(store: store.scope(state: \.recordingListScreen, action: \.recordingListScreen))
            .applyTabBarContentInset()
        } destination: { store in
          switch store.case {
          case let .details(store):
            RecordingDetailsView(store: store)
              .background(Color.DS.Background.primary)
              .applyTabBarContentInset()
          }
        }
        .navigationTransition(.slide),
        screen2: RecordScreenView(store: store.scope(state: \.recordScreen, action: \.recordScreen)),
        screen3: NavigationStack {
          SettingsScreenView(store: store.scope(state: \.settingsScreen, action: \.settingsScreen))
        }
      )
      .accentColor(.white)
      .task { await store.send(.task).finish() }
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
