import AppDevUtils
import ComposableArchitecture
import SwiftUI

// MARK: - Root

struct Root: ReducerProtocol {
  struct State: Equatable {
    var recordingListScreen = RecordingListScreen.State()
    var recordScreen = RecordScreen.State()
    var settings = Settings.State()
    var selectedTab = 0
  }

  enum Action: Equatable {
    case recordingListScreen(RecordingListScreen.Action)
    case recordScreen(RecordScreen.Action)
    case settings(Settings.Action)
    case selectTab(Int)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.recordingListScreen, action: /Action.recordingListScreen) {
      RecordingListScreen()
    }

    CombineReducers {
      Scope(state: \.recordScreen, action: /Action.recordScreen) {
        RecordScreen()
      }

      Reduce<State, Action> { state, action in
        switch action {
        case let .recordScreen(.newRecordingCreated(recordingInfo)):
          let recordingCard = RecordingCard.State(recordingInfo: recordingInfo)
          state.recordingListScreen.recordings.insert(recordingCard, at: 0)
          state.recordingListScreen.selection = nil
          return .run { send in
            await send(.selectTab(0))
            await send(.recordingListScreen(.recordingSelected(id: recordingInfo.id)))
          }

        default:
          return .none
        }
      }
    }

    Scope(state: \.settings, action: /Action.settings) {
      Settings()
    }

    Reduce { state, action in
      switch action {
      case let .selectTab(tab):
        state.selectedTab = tab
        return .none
      default:
        return .none
      }
    }
  }
}

// MARK: - RootView

struct RootView: View {
  let store: StoreOf<Root>
  @ObservedObject var viewStore: ViewStoreOf<Root>

  init(store: StoreOf<Root>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  var body: some View {
    WithViewStore(store) { viewStore in
      TabView(selection: viewStore.binding(get: { $0.selectedTab }, send: Root.Action.selectTab)) {
        RecordingListScreenView(store: store.scope(state: \.recordingListScreen, action: Root.Action.recordingListScreen))
          .accentColor(Color.DS.Text.base)
          .tabItem {
            Image(systemName: "list.bullet")
            Text("Recordings")
          }
          .tag(0)

        RecordScreenView(store: store.scope(state: { $0.recordScreen }, action: Root.Action.recordScreen))
          .accentColor(Color.DS.Text.base)
          .tabItem {
            Image(systemName: "mic")
            Text("Record")
          }
          .tag(1)

        SettingsView(store: store.scope(state: { $0.settings }, action: Root.Action.settings))
          .accentColor(Color.DS.Text.base)
          .tabItem {
            Image(systemName: "gear")
            Text("Settings")
          }
          .tag(2)
      }
      .task { viewStore.send(.settings(.modelSelector(.task))) }
    }
    .accentColor(Color.DS.Text.accent)
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
