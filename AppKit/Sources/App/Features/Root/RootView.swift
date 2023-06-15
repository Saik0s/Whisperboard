import AppDevUtils
import Combine
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RootView

struct RootView: View {
  @ObserveInjection var inject

  let store: StoreOf<Root>

  @ObservedObject var viewStore: ViewStoreOf<Root>

  @Namespace var animation

  init(store: StoreOf<Root>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  private var selectedTab: Int {
    viewStore.selectedTab.rawValue
  }

  var body: some View {
    CustomTabBarView(
      selectedIndex: viewStore.binding(get: \.selectedTab.rawValue, send: Root.Action.selectTab),
      screen1: RecordingListScreenView(store: store.scope(state: \.recordingListScreen, action: Root.Action.recordingListScreen)),
      screen2: RecordScreenView(store: store.scope(state: \.recordScreen, action: Root.Action.recordScreen)),
      screen3: SettingsScreenView(store: store.scope(state: \.settings, action: Root.Action.settings))
    )
    .animation(.gentleBounce(), value: selectedTab)
    .task { viewStore.send(.task) }
    .enableInjection()
  }
}

// MARK: - TabBarItem

struct TabBarItem: View {
  let icon: String

  let tag: Int

  @Binding var selectedTab: Int

  var body: some View {
    Button(action: {
      withAnimation(.gentleBounce()) {
        selectedTab = tag
      }
    }) {
      Image(systemName: icon)
        .font(selectedTab == tag ? .DS.headlineM.weight(.bold) : .DS.headlineM.weight(.light))
        .frame(width: 50, height: 50)
        .foregroundColor(selectedTab == tag ? Color.DS.Text.accent : Color.DS.Text.base)
        .cornerRadius(10)
    }
  }
}

// MARK: - Root_Previews

struct Root_Previews: PreviewProvider {
  struct ContentView: View {
    var body: some View {
      RootView(
        store: Store(
          initialState: Root.State(),
          reducer: Root()
        )
      )
    }
  }

  static var previews: some View {
    ContentView()
  }
}
