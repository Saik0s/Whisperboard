import ComposableArchitecture
import SwiftUI

// MARK: - Root

struct Root: ReducerProtocol {
  struct State: Equatable {
    var whisperList = WhisperList.State()
  }

  enum Action: Equatable {
    case whisperList(WhisperList.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.whisperList, action: /Action.whisperList) { WhisperList() }

    Reduce { _, _ in
      .none
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
    WhisperListView(store: store.scope(state: \.whisperList, action: Root.Action.whisperList))
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
