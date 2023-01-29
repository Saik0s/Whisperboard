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

    var _whisperList = WhisperList.State()
    var whisperList: WhisperList.State {
      get {
        _whisperList.with {
          $0.settings = settings
        }
      }
      set {
        _whisperList = newValue
      }
    }
  }

  enum Action: Equatable {
    case recordingListScreen(RecordingListScreen.Action)
    case recordScreen(RecordScreen.Action)
    case settings(Settings.Action)
    case selectTab(Int)

    case whisperList(WhisperList.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.recordingListScreen, action: /Action.recordingListScreen) {
      RecordingListScreen()
    }
    Scope(state: \.recordScreen, action: /Action.recordScreen) {
      RecordScreen()
    }
    Scope(state: \.settings, action: /Action.settings) {
      Settings()
    }

    Scope(state: \.whisperList, action: /Action.whisperList) { WhisperList() }

    Reduce { state, action in
      switch action {
      case .selectTab(let tab):
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
        WhisperListView(store: store.scope(state: \.whisperList, action: Root.Action.whisperList))
          .tabItem {
            Image(systemName: "1.circle")
            Text("Recordings")
          }
          .tag(0)

        RecordScreenView(store: store.scope(state: { $0.recordScreen }, action: Root.Action.recordScreen))
          .tabItem {
            Image(systemName: "mic")
            Text("Record")
          }
          .tag(1)

        SettingsView(store: store.scope(state: { $0.settings }, action: Root.Action.settings))
          .tabItem {
            Image(systemName: "gear")
            Text("Settings")
          }
          .tag(2)
      }
        .task { viewStore.send(.settings(.modelSelector(.task))) }
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
